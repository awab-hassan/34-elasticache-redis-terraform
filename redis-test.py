# Python script to test Redis connection
import redis

def test_redis_connection():
    # Initialize Redis connection
    r = redis.Redis(
        host='redis-cluster.s3psra.0001.apne1.cache.amazonaws.com',
        port=6379,
        decode_responses=True  # This will decode bytes to strings
    )
    
    try:
        # Test basic connection
        print("Testing connection...")
        response = r.ping()
        print(f"Connection test: {'Success' if response else 'Failed'}")
        
        # Test write operation
        print("\nTesting write operation...")
        r.set('test_key', 'test_value')
        print("Write operation: Success")
        
        # Test read operation
        print("\nTesting read operation...")
        value = r.get('test_key')
        print(f"Read operation: {value}")
        
        # Test data types
        print("\nTesting different data types...")
        
        # List
        r.lpush('test_list', 'item1', 'item2')
        list_items = r.lrange('test_list', 0, -1)
        print(f"List test: {list_items}")
        
        # Hash
        r.hset('test_hash', mapping={'field1': 'value1', 'field2': 'value2'})
        hash_items = r.hgetall('test_hash')
        print(f"Hash test: {hash_items}")
        
        # Set
        r.sadd('test_set', 'member1', 'member2')
        set_items = r.smembers('test_set')
        print(f"Set test: {set_items}")
        
        # Clean up
        print("\nCleaning up test data...")
        r.delete('test_key', 'test_list', 'test_hash', 'test_set')
        
    except redis.ConnectionError as e:
        print(f"Connection Error: {e}")
    except redis.RedisError as e:
        print(f"Redis Error: {e}")
    finally:
        r.close()

if __name__ == "__main__":
    test_redis_connection()