package models

import (
	"math/rand"
	"strconv"
	"testing"
	"time"

	uuid "github.com/satori/go.uuid"
	"github.com/semaphoreio/semaphore/artifacthub/pkg/db"
	"github.com/semaphoreio/semaphore/artifacthub/pkg/util/retry"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"gorm.io/gorm"
)

func init() {
	retry.Limit = 2
	retry.StartTimeout = time.Duration(200)
	retry.AddTimeout = time.Duration(100)
}

func compareArtifact(t *testing.T, a *Artifact, err error, descr, s string) {
	assert.Nilf(t, err, descr)
	assert.Equalf(t, a.BucketName, s, descr)
	assert.Equalf(t, a.IdempotencyToken, s, descr)
}

func checkNext(t *testing.T, lastBucketName, expBucketName string) {
	bucketName, err := FindNextBucket(lastBucketName)
	assert.Nil(t, err, "next bucket name should return no error")
	assert.Equal(t, expBucketName, bucketName, "next bucket name should match")
}

func checkNextLast(t *testing.T, lastBucketName string) {
	bucketName, err := FindNextBucket(lastBucketName)
	assert.Nil(t, err, "next bucket name should return no error")
	assert.Len(t, bucketName, 0, "next bucket name should be empty as the last one")
}

func TestArtifact(t *testing.T) {
	PrepareDatabaseForTests()

	// checking some rows that should NOT exist
	someUUID := uuid.NewV1()
	someUUIDS := someUUID.String()

	testNotCreatedArtifacts := func() {
		a, err := findArtifactByID(db.Conn(), someUUIDS)
		require.Nil(t, a)
		require.ErrorIs(t, err, gorm.ErrRecordNotFound)
		a, err = findArtifactByIdempotencyToken(someUUIDS)
		require.Nil(t, a)
		require.ErrorIs(t, err, gorm.ErrRecordNotFound)
	}

	testNotCreatedArtifacts()
	checkNextLast(t, "")

	// adding some records
	someUUID2 := uuid.NewV1()
	someUUIDS2 := someUUID2.String()
	a, err := CreateArtifact(someUUIDS2, someUUIDS2)
	compareArtifact(t, a, err, "inserting Artifact", someUUIDS2)
	checkNext(t, "", someUUIDS2)
	checkNextLast(t, someUUIDS2)

	someUUID3 := uuid.NewV1()
	someUUIDS3 := someUUID3.String()
	b, err := CreateArtifact(someUUIDS3, someUUIDS3)
	compareArtifact(t, b, err, "inserting Artifact", someUUIDS3)
	checkNext(t, someUUIDS2, someUUIDS3)
	checkNextLast(t, someUUIDS3)

	// still not finding the ones that weren't added
	testNotCreatedArtifacts()

	// being able to find others
	b, err = FindArtifactByID(b.ID.String())
	compareArtifact(t, b, err, "finding by id", someUUIDS3)
	a, err = FindArtifactByIdempotencyToken(someUUIDS2)
	compareArtifact(t, a, err, "finding by idempotency token", someUUIDS2)
	a, err = FindArtifactByID(a.ID.String())
	compareArtifact(t, a, err, "finding by token", someUUIDS2)
	b, err = FindArtifactByID(b.ID.String())
	compareArtifact(t, b, err, "finding by token", someUUIDS3)

	// deleting the first one, and recheck
	err = a.Destroy()
	assert.Nilf(t, err, "finding by id")
	a, err = findArtifactByID(db.Conn(), someUUIDS2)
	require.Nil(t, a)
	require.ErrorIs(t, err, gorm.ErrRecordNotFound)
	a, err = findArtifactByIdempotencyToken(someUUIDS2)
	require.Nil(t, a)
	require.ErrorIs(t, err, gorm.ErrRecordNotFound)
	checkNext(t, "", someUUIDS3)
	checkNextLast(t, someUUIDS2)
	checkNextLast(t, someUUIDS3)

	// b is still available
	b, err = FindArtifactByID(b.ID.String())
	compareArtifact(t, b, err, "finding by token", someUUIDS3)
}

func checkIterBuckets(t *testing.T, exp []string, descr string) {
	i := 0
	err := IterAllBuckets(func(bucketName string) {
		if len(exp) <= i {
			require.Failf(t, "IterAllBuckets index out of range", "at bucket %s for '%s'",
				bucketName, descr)
		}
		assert.Equal(t, exp[i], bucketName, "IterAllBuckets item no. %d should match for '%s'",
			i, descr)
		i++
	})
	assert.Nilf(t, err, "IterAllBuckets error should be nil for '%s'", descr)
	assert.Lenf(t, exp, i, "IterAllBuckets lenght should match for '%s'", descr)
}

func TestArtifactList(t *testing.T) {
	rand.Seed(time.Now().UnixNano())
	PrepareDatabaseForTests()

	numToTest := 200
	compareList := make([]string, numToTest)
	mapAll := map[string]string{}

	checkIterBuckets(t, nil, "listing artifact bucket names when none exist")
	for i := 0; i < numToTest; i++ {
		bucketName := strconv.Itoa(i)
		a, err := CreateArtifact(bucketName, bucketName)
		assert.Nilf(t, err, "creating artifact")
		compareList[i] = bucketName
		mapAll[a.ID.String()] = a.BucketName

		checkIterBuckets(t, compareList[:i+1], "comparing artifact bucket names")
	}
	ids := make([]string, 50)
	for i := 0; i < 20; i++ {
		maxJ := rand.Intn(40) + 10
		expM := map[string]string{}
		j := 0
		for id, bucketName := range mapAll {
			ids[j] = id
			expM[id] = bucketName
			j++
			if j >= maxJ {
				break
			}
		}
		m, err := ListBucketsForIDs(ids[:j])
		assert.Nilf(t, err, "listing bucket names for artifact ids")
		assert.Equalf(t, m, expM, "listing bucket names for artifact ids")
	}
}

func Test__UpdateLastCleanedAt(t *testing.T) {
	PrepareDatabaseForTests()

	artifact, _ := CreateArtifact("bucket_name", "this_is_token")
	lastCleanedAt := time.Now()

	err := artifact.UpdateLastCleanedAt(lastCleanedAt)
	assert.Nil(t, err)
	assert.Equal(t, lastCleanedAt.Unix(), artifact.LastCleanedAt.Unix())

	//check if the change is actually in the db
	storedArtifact, err := FindArtifactByIdempotencyToken("this_is_token")
	assert.Nil(t, err)
	assert.Equal(t, storedArtifact.LastCleanedAt.Unix(), lastCleanedAt.Unix())
}

func Test__FetchForCleaning(t *testing.T) {
	t.Run("when the bucket was never cleaned before", func(t *testing.T) {
		PrepareDatabaseForTests()

		artifact, _ := CreateArtifact("bucket_name", "this_is_token")

		buckets, err := FetchForCleaning()

		assert.Nil(t, err)
		assert.Equal(t, 1, len(buckets))
		assert.Equal(t, artifact.ID, buckets[0].ID)
	})

	t.Run("when the bucket's last cleaning date is not today", func(t *testing.T) {
		PrepareDatabaseForTests()

		artifact, _ := CreateArtifact("bucket_name", "this_is_token")
		yesterday := time.Now().AddDate(0, 0, -1)
		artifact.UpdateLastCleanedAt(yesterday)

		buckets, err := FetchForCleaning()

		assert.Nil(t, err)
		assert.Equal(t, 1, len(buckets))
		assert.Equal(t, artifact.ID, buckets[0].ID)
	})

	t.Run("when the bucket was last cleaned today", func(t *testing.T) {
		PrepareDatabaseForTests()

		artifact, _ := CreateArtifact("bucket_name", "this_is_token")
		today := time.Now()
		artifact.UpdateLastCleanedAt(today)

		buckets, err := FetchForCleaning()

		assert.Nil(t, err)
		assert.Equal(t, 0, len(buckets))
	})
}
