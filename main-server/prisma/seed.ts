import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
  console.log('🌱 Seeding database...');

  // Create subscription plans
  const plans = [
    {
      id: 'hourly',
      name: 'Hourly Bundle',
      description: 'Unlimited internet for 1 hour',
      price: 10,
      currency: 'KES',
      durationHours: 1,
      isActive: true,
      sortOrder: 1,
    },
    {
      id: 'daily',
      name: 'Daily Bundle',
      description: 'Unlimited internet for 24 hours',
      price: 30,
      currency: 'KES',
      durationHours: 24,
      isActive: true,
      sortOrder: 2,
    },
    {
      id: 'weekly',
      name: 'Weekly Bundle',
      description: 'Unlimited internet for 7 days',
      price: 150,
      currency: 'KES',
      durationHours: 168,
      isActive: true,
      sortOrder: 3,
    },
    {
      id: 'monthly',
      name: 'Monthly Bundle',
      description: 'Unlimited internet for 30 days',
      price: 500,
      currency: 'KES',
      durationHours: 720,
      isActive: true,
      sortOrder: 4,
    },
  ];

  for (const plan of plans) {
    await prisma.plan.upsert({
      where: { id: plan.id },
      update: plan,
      create: plan,
    });
    console.log(`  ✅ Plan: ${plan.name} (KES ${plan.price})`);
  }

  // Create a test user
  const testUser = await prisma.user.upsert({
    where: { phone: '254700000000' },
    update: {},
    create: {
      phone: '254700000000',
      referralCode: 'TEST001',
      autoRenew: false,
    },
  });
  console.log(`  ✅ Test user: ${testUser.phone} (${testUser.id})`);

  // Create a test reseller
  const testReseller = await prisma.user.upsert({
    where: { phone: '254711111111' },
    update: {},
    create: {
      phone: '254711111111',
      referralCode: 'RESELL1',
      autoRenew: false,
    },
  });

  await prisma.reseller.upsert({
    where: { userId: testReseller.id },
    update: {},
    create: {
      userId: testReseller.id,
      deviceId: 'test-rpi-001',
      location: 'Nairobi, Kenya',
      capacity: 100,
      compensationType: 'COMMISSION',
      commissionRate: 20.00,
      platform: 'rpi',
      version: '1.0.0',
    },
  });
  console.log(`  ✅ Test reseller: ${testReseller.phone}`);

  console.log('\n✅ Seeding completed successfully!');
}

main()
  .catch((e) => {
    console.error('❌ Seeding failed:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
