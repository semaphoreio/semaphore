package events

//
// This is the event that is emitted when a stage finishes its execution.
//

type StageCompletionEvent struct {
	Stage  Stage
	Result string
}

type Stage struct {
	ID string
}
