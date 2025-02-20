package storage

import (
	"time"

	gcsstorage "cloud.google.com/go/storage"
	"google.golang.org/api/iterator"
)

type GcsObjectPager struct {
	pager *iterator.Pager
}

func (i *GcsObjectPager) NextPage() ([]*Object, string, error) {
	rawObjects := []*gcsstorage.ObjectAttrs{}
	nextPageToken, err := i.pager.NextPage(&rawObjects)
	if err != nil {
		return []*Object{}, "", err
	}

	result := []*Object{}

	for i := 0; i < len(rawObjects); i++ {
		age := time.Since(rawObjects[i].Created)
		result = append(result, &Object{
			Path: rawObjects[i].Name,
			Age:  &age,
		})
	}

	return result, nextPageToken, nil
}
