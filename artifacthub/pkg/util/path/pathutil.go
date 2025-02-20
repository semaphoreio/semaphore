package pathutil

import (
	"path"

	"github.com/semaphoreio/semaphore/artifacthub/pkg/api/descriptors/artifacthub"
)

// CategoryPath returns path in the bucket that represents a category (project/workflow/job)
// with its unique ID, eg. artifacts/projects/<projectID>.
func CategoryPath(category artifacthub.CountArtifactsRequest_Category, categoryID string) string {
	var categoryName string
	switch category {
	case artifacthub.CountArtifactsRequest_PROJECT:
		categoryName = "projects"
	case artifacthub.CountArtifactsRequest_WORKFLOW:
		categoryName = "workflows"
	case artifacthub.CountArtifactsRequest_JOB:
		categoryName = "jobs"
	}

	return path.Join("artifacts", categoryName, categoryID)
}

const (
	// ExpirePrefix is where object expires are stored in the same bucket.
	ExpirePrefix = "var/expires-in/"
	// LockPath may exists if another worker is cleaning the bucket right now.
	LockPath = "var/lock"
)

// CheckEndsInSlash returns if the path looks like a directory.
func CheckEndsInSlash(in string) bool {
	return len(in) == 0 || in[len(in)-1] == '/'
}

// EndsInSlash makes sure to have a slash at the end of the given string.
func EndsInSlash(in string) string {
	if len(in) > 0 && in[len(in)-1] != '/' {
		in = in + "/"
	}
	return in
}

// NotEndsInSlash makes sure NOT to have a slash at the end of the given string.
func NotEndsInSlash(in string) string {
	if len(in) > 0 && in[len(in)-1] == '/' {
		in = in[:len(in)-1]
	}
	return in
}

// GetDir returns parent directory for a given path.
func GetDir(p string) string {
	dir := path.Dir(p)
	if dir == "." || dir == "/" {
		dir = ""
	}
	return dir
}

// Split returns dir and object name from a path.
func Split(p string) (string, string) {
	p = NotEndsInSlash(p)
	return GetDir(p), path.Base(p)
}
