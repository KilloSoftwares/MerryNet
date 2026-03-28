use actix_cors::Cors;
use actix_web::{get, post, web, App, HttpRequest, HttpResponse, HttpServer, middleware};
use chrono::Utc;
use serde::{Deserialize, Serialize};
use std::env;
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::Arc;
use std::time::Instant;

// ============================================================
// State & Types
// ============================================================

struct AppState {
    start_time: Instant,
    request_count: AtomicU64,
    main_server_url: String,
}

#[derive(Serialize)]
struct HealthResponse {
    status: &'static str,
    service: &'static str,
    version: &'static str,
    timestamp: String,
    uptime_seconds: u64,
    requests_served: u64,
}

#[derive(Serialize)]
struct PingResponse {
    status: &'static str,
    timestamp: String,
}

#[derive(Deserialize)]
struct PaymentInitRequest {
    phone: String,
    plan_id: String,
}

#[derive(Serialize)]
struct ApiResponse<T: Serialize> {
    success: bool,
    data: Option<T>,
    error: Option<String>,
}

impl<T: Serialize> ApiResponse<T> {
    fn ok(data: T) -> Self {
        Self {
            success: true,
            data: Some(data),
            error: None,
        }
    }

    fn err(message: &str) -> ApiResponse<()> {
        ApiResponse::<()> {
            success: false,
            data: None,
            error: Some(message.to_string()),
        }
    }
}

// ============================================================
// Handlers
// ============================================================

/// Minimal ping endpoint — used by zero-rated bootstrap
#[get("/ping")]
async fn ping(data: web::Data<Arc<AppState>>) -> HttpResponse {
    data.request_count.fetch_add(1, Ordering::Relaxed);
    HttpResponse::Ok().json(PingResponse {
        status: "ok",
        timestamp: Utc::now().to_rfc3339(),
    })
}

/// Health check with uptime and stats
#[get("/health")]
async fn health(data: web::Data<Arc<AppState>>) -> HttpResponse {
    data.request_count.fetch_add(1, Ordering::Relaxed);
    let uptime = data.start_time.elapsed().as_secs();
    let requests = data.request_count.load(Ordering::Relaxed);

    HttpResponse::Ok().json(HealthResponse {
        status: "healthy",
        service: "maranet-bootstrap",
        version: "1.0.0",
        timestamp: Utc::now().to_rfc3339(),
        uptime_seconds: uptime,
        requests_served: requests,
    })
}

/// Root endpoint — returns service info
#[get("/")]
async fn index(data: web::Data<Arc<AppState>>) -> HttpResponse {
    data.request_count.fetch_add(1, Ordering::Relaxed);
    HttpResponse::Ok().json(serde_json::json!({
        "service": "Maranet Zero Bootstrap",
        "version": "1.0.0",
        "endpoints": ["/ping", "/health", "/payment/initiate"],
        "status": "ok"
    }))
}

/// Fallback payment initiation — forwards to main server
/// Used when user has zero balance and can only reach zero-rated domains
#[post("/payment/initiate")]
async fn initiate_payment(
    data: web::Data<Arc<AppState>>,
    body: web::Json<PaymentInitRequest>,
) -> HttpResponse {
    data.request_count.fetch_add(1, Ordering::Relaxed);

    let client = reqwest::Client::new();
    let url = format!("{}/api/v1/payments/initiate", data.main_server_url);

    match client
        .post(&url)
        .json(&serde_json::json!({
            "phone": body.phone,
            "planId": body.plan_id,
        }))
        .timeout(std::time::Duration::from_secs(15))
        .send()
        .await
    {
        Ok(response) => {
            let status = response.status();
            match response.text().await {
                Ok(text) => {
                    if let Ok(json) = serde_json::from_str::<serde_json::Value>(&text) {
                        HttpResponse::build(status).json(json)
                    } else {
                        HttpResponse::build(status).body(text)
                    }
                }
                Err(_) => HttpResponse::BadGateway().json(ApiResponse::<()>::err(
                    "Failed to read response from payment server",
                )),
            }
        }
        Err(e) => {
            log::error!("Payment proxy error: {}", e);
            HttpResponse::ServiceUnavailable().json(ApiResponse::<()>::err(
                "Payment service temporarily unavailable. Please try again.",
            ))
        }
    }
}

/// Plans endpoint — returns available plans (cached locally for speed)
#[get("/plans")]
async fn get_plans(data: web::Data<Arc<AppState>>) -> HttpResponse {
    data.request_count.fetch_add(1, Ordering::Relaxed);

    HttpResponse::Ok().json(ApiResponse::ok(serde_json::json!([
        {
            "id": "hourly",
            "name": "Hourly Bundle",
            "description": "Unlimited internet for 1 hour",
            "price": 10,
            "currency": "KES",
            "duration_hours": 1
        },
        {
            "id": "daily",
            "name": "Daily Bundle",
            "description": "Unlimited internet for 24 hours",
            "price": 30,
            "currency": "KES",
            "duration_hours": 24
        },
        {
            "id": "weekly",
            "name": "Weekly Bundle",
            "description": "Unlimited internet for 7 days",
            "price": 150,
            "currency": "KES",
            "duration_hours": 168
        },
        {
            "id": "monthly",
            "name": "Monthly Bundle",
            "description": "Unlimited internet for 30 days",
            "price": 500,
            "currency": "KES",
            "duration_hours": 720
        }
    ])))
}

/// Carrier detection helper — returns carrier info based on request headers
#[get("/carrier")]
async fn detect_carrier(req: HttpRequest, data: web::Data<Arc<AppState>>) -> HttpResponse {
    data.request_count.fetch_add(1, Ordering::Relaxed);

    // Try to detect carrier from X-Forwarded-For header patterns
    let ip = req
        .connection_info()
        .realip_remote_addr()
        .unwrap_or("unknown")
        .to_string();

    HttpResponse::Ok().json(serde_json::json!({
        "ip": ip,
        "carrier": "unknown",
        "country": "KE",
        "zero_rated_domains": [
            "free.facebook.com.maranet.app",
            "zero.maranet.app"
        ]
    }))
}

// ============================================================
// Main
// ============================================================

#[actix_web::main]
async fn main() -> std::io::Result<()> {
    dotenv::dotenv().ok();
    env_logger::init_from_env(env_logger::Env::default().default_filter_or("info"));

    let host = env::var("HOST").unwrap_or_else(|_| "0.0.0.0".to_string());
    let port: u16 = env::var("PORT")
        .unwrap_or_else(|_| "8080".to_string())
        .parse()
        .expect("PORT must be a number");
    let main_server_url =
        env::var("MAIN_SERVER_URL").unwrap_or_else(|_| "http://localhost:3000".to_string());

    let state = Arc::new(AppState {
        start_time: Instant::now(),
        request_count: AtomicU64::new(0),
        main_server_url,
    });

    log::info!(
        r#"
╔══════════════════════════════════════════════════════╗
║                                                      ║
║        🚀 Maranet Bootstrap API                      ║
║                                                      ║
║   Listening on: {}:{}                        ║
║   Rust + Actix-Web                                   ║
║   Minimal footprint for zero-rated access            ║
║                                                      ║
╚══════════════════════════════════════════════════════╝
"#,
        host, port
    );

    HttpServer::new(move || {
        let cors = Cors::default()
            .allow_any_origin()
            .allow_any_method()
            .allow_any_header()
            .max_age(3600);

        App::new()
            .app_data(web::Data::new(state.clone()))
            .wrap(cors)
            .wrap(middleware::Logger::default())
            .wrap(middleware::Compress::default())
            .service(index)
            .service(ping)
            .service(health)
            .service(get_plans)
            .service(initiate_payment)
            .service(detect_carrier)
    })
    .bind(format!("{}:{}", host, port))?
    .workers(2) // Lightweight — 2 workers is enough
    .run()
    .await
}
