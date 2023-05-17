package workerpool

type Config struct {
	PoolSize        int
	TaskQueueLength int
}

func (c Config) withDefaults() Config {
	if c.TaskQueueLength == 0 {
		c.TaskQueueLength = 10
	}

	if c.PoolSize == 0 {
		c.PoolSize = 3
	}

	return c
}
