# client

This client may connect to private gRPC server, and call CORS related gRPC functions.

## Global flags:
* `--server-address` OR `-a` is where the private server can be accessed, mainly in the form of `HOST[:PORT]`

## Commands
* `updateCorsSingle` updates one bucket given by its name; flags:
  * `--bucket-name` OR `-b` required: the name of the bucket to update

* `updateCors` updates multiple buckets; flags:
  * `--start-bucket-name` OR `-s` the first bucket to update, if empty: starts from the top
  * `--count` OR `-c` the number of buckets to update, if empty or zero: till the end
  * `--index-diff` OR `-d` the index of the first bucket if `--start-bucket-name` is set but `--count` is not, set to -1 if you don't know it
  * `--wait-ms` OR `-w` wait this amount of time in milliseconds between two update calls

* `currentNumberOfBuckets` returns number of current buckets (in the database), mostly for testing purposes
