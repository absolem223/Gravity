class_name ActionState
extends RefCounted

## Public state machine contract for the Action System.
enum State {
	IDLE,
	REQUESTED,
	READY,
	ACTIVE,
	CANCELLED,
	BLOCKED,
	FINISHED,
	FAILED,
}
