package workerpool

import (
	"sync"
)

type WorkerPool struct {
	taskQueue chan func()

	wg sync.WaitGroup

	closed   bool
	mu       sync.RWMutex
	stopOnce sync.Once
}

func New(cfg Config) *WorkerPool {
	cfg = cfg.withDefaults()

	pool := WorkerPool{
		taskQueue: make(chan func(), cfg.TaskQueueLength),
	}

	pool.wg.Add(cfg.PoolSize)
	for i := 0; i < cfg.PoolSize; i++ {
		go func() {
			defer pool.wg.Done()
			pool.startWorker()
		}()
	}

	return &pool
}

func (p *WorkerPool) AddTask(task func()) {
	p.mu.RLock()
	if p.closed {
		p.mu.RUnlock()
		return
	}
	p.mu.RUnlock()

	p.taskQueue <- task
}

func (p *WorkerPool) Close() {
	p.stopOnce.Do(func() {
		p.mu.Lock()
		// stop receiving new tasks
		p.closed = true
		// close task queue.
		close(p.taskQueue)
		p.mu.Unlock()
		// wait for workers to handle left tasks in the queue
		p.wg.Wait()
	})
}

func (p *WorkerPool) startWorker() {
	for task := range p.taskQueue {
		task()
	}
}
