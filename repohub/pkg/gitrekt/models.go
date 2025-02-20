package gitrekt

type File struct {
	Path    string
	Content string
}

type Revision struct {
	CommitSha string
	Reference string
}
