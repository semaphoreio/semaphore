package service

import (
	"bytes"
	"context"
	"encoding/gob"
	"log"
	"time"

	bigcache "github.com/allegro/bigcache/v3"
	"github.com/eko/gocache/lib/v4/cache"
	bigcache_store "github.com/eko/gocache/store/bigcache/v4"
)

type CacheGoClient struct {
	cache *cache.Cache[[]byte]
}

type CacheClient interface {
	Get(ctx context.Context, key string, value interface{}) error
	Set(ctx context.Context, key string, value interface{}) error
}

func NewCacheService() CacheClient {
	ctx := context.Background()
	bigCacheInstance, _ := bigcache.New(ctx, bigcache.DefaultConfig(10*time.Minute))
	bigCacheStore := bigcache_store.NewBigcache(bigCacheInstance)
	cacheInstance := cache.New[[]byte](bigCacheStore)

	return &CacheGoClient{cache: cacheInstance}
}

func (c *CacheGoClient) Get(ctx context.Context, key string, value interface{}) error {
	bytesValue, err := c.cache.Get(ctx, key)
	if err != nil {
		return err
	}

	err = deserialize(bytesValue, value)
	if err != nil {
		return err
	}

	return nil
}

func (c *CacheGoClient) Set(ctx context.Context, key string, value interface{}) error {
	serializedValue, err := serialize(value)
	if err != nil {
		return err
	}

	return c.cache.Set(ctx, key, serializedValue)
}

func serialize(value interface{}) ([]byte, error) {
	buf := bytes.Buffer{}
	enc := gob.NewEncoder(&buf)

	err := enc.Encode(value)
	if err != nil {
		log.Printf("Error serializing value: %v", err)
		return nil, err
	}

	return buf.Bytes(), nil
}

func deserialize(valueBytes []byte, value interface{}) error {
	buf := bytes.NewBuffer(valueBytes)
	dec := gob.NewDecoder(buf)

	err := dec.Decode(value)
	if err != nil {
		log.Printf("Error serializing value: %v", err)
		return err
	}

	return nil
}
