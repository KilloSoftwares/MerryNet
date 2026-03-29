package core

import (
	"context"
	"fmt"
	"sync"
	"time"

	log "github.com/sirupsen/logrus"
)

// Message represents inter-component communication
type Message struct {
	Type      string
	From      string
	To        string
	Payload   interface{}
	Timestamp time.Time
}

// Component interface for all Sky OS components
type Component interface {
	Name() string
	Start(ctx context.Context) error
	Stop() error
	HandleMessage(msg Message) error
}

// Kernel is the microkernel core of Sky OS
type Kernel struct {
	components map[string]Component
	messageBus chan Message
	mu         sync.RWMutex
	ctx        context.Context
	cancel     context.CancelFunc
}

// NewKernel creates a new Sky OS kernel instance
func NewKernel() *Kernel {
	return &Kernel{
		components: make(map[string]Component),
		messageBus: make(chan Message, 1000),
	}
}

// RegisterComponent adds a component to the kernel
func (k *Kernel) RegisterComponent(component Component) error {
	k.mu.Lock()
	defer k.mu.Unlock()

	name := component.Name()
	if _, exists := k.components[name]; exists {
		return fmt.Errorf("component %s already registered", name)
	}

	k.components[name] = component
	log.Infof("Registered component: %s", name)
	return nil
}

// UnregisterComponent removes a component from the kernel
func (k *Kernel) UnregisterComponent(name string) error {
	k.mu.Lock()
	defer k.mu.Unlock()

	if _, exists := k.components[name]; !exists {
		return fmt.Errorf("component %s not found", name)
	}

	delete(k.components, name)
	log.Infof("Unregistered component: %s", name)
	return nil
}

// SendMessage sends a message to a specific component
func (k *Kernel) SendMessage(msg Message) error {
	if msg.Timestamp.IsZero() {
		msg.Timestamp = time.Now()
	}

	select {
	case k.messageBus <- msg:
		return nil
	default:
		return fmt.Errorf("message bus full, dropping message")
	}
}

// BroadcastMessage sends a message to all components
func (k *Kernel) BroadcastMessage(msg Message) error {
	k.mu.RLock()
	defer k.mu.RUnlock()

	for name, component := range k.components {
		if name != msg.From { // Don't send to sender
			go func(c Component, m Message) {
				if err := c.HandleMessage(m); err != nil {
					log.Errorf("Component %s failed to handle message: %v", c.Name(), err)
				}
			}(component, msg)
		}
	}
	return nil
}

// Start initializes and starts all registered components
func (k *Kernel) Start(ctx context.Context) error {
	k.ctx, k.cancel = context.WithCancel(ctx)

	log.Info("Starting Sky OS Kernel...")

	// Start message bus
	go k.runMessageBus()

	// Start all components
	k.mu.RLock()
	components := make([]Component, 0, len(k.components))
	for _, comp := range k.components {
		components = append(components, comp)
	}
	k.mu.RUnlock()

	for _, component := range components {
		if err := component.Start(k.ctx); err != nil {
			return fmt.Errorf("failed to start component %s: %v", component.Name(), err)
		}
		log.Infof("Started component: %s", component.Name())
	}

	log.Info("Sky OS Kernel started successfully")
	return nil
}

// Stop gracefully shuts down all components
func (k *Kernel) Stop() error {
	if k.cancel != nil {
		k.cancel()
	}

	k.mu.RLock()
	defer k.mu.RUnlock()

	var wg sync.WaitGroup
	errChan := make(chan error, len(k.components))

	for _, component := range k.components {
		wg.Add(1)
		go func(comp Component) {
			defer wg.Done()
			if err := comp.Stop(); err != nil {
				errChan <- fmt.Errorf("failed to stop component %s: %v", comp.Name(), err)
			}
		}(component)
	}

	wg.Wait()
	close(errChan)

	var errs []error
	for err := range errChan {
		errs = append(errs, err)
	}

	if len(errs) > 0 {
		return fmt.Errorf("errors during shutdown: %v", errs)
	}

	log.Info("Sky OS Kernel stopped successfully")
	return nil
}

// runMessageBus handles message routing between components
func (k *Kernel) runMessageBus() {
	for {
		select {
		case <-k.ctx.Done():
			return
		case msg := <-k.messageBus:
			if msg.To == "" {
				// Broadcast message
				k.BroadcastMessage(msg)
			} else {
				// Direct message
				k.mu.RLock()
				component, exists := k.components[msg.To]
				k.mu.RUnlock()

				if exists {
					if err := component.HandleMessage(msg); err != nil {
						log.Errorf("Component %s failed to handle message: %v", msg.To, err)
					}
				} else {
					log.Warnf("Message for unknown component %s", msg.To)
				}
			}
		}
	}
}

// GetComponent returns a component by name
func (k *Kernel) GetComponent(name string) (Component, bool) {
	k.mu.RLock()
	defer k.mu.RUnlock()
	component, exists := k.components[name]
	return component, exists
}

// ListComponents returns all registered component names
func (k *Kernel) ListComponents() []string {
	k.mu.RLock()
	defer k.mu.RUnlock()
	names := make([]string, 0, len(k.components))
	for name := range k.components {
		names = append(names, name)
	}
	return names
}