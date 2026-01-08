extends Object
class_name TestErrorGuard

static func suppress_engine_errors(test: GutTest) -> int:
	var previous = test.gut.error_tracker.treat_engine_errors_as
	test.gut.error_tracker.treat_engine_errors_as = GutUtils.TREAT_AS.NOTHING
	return previous

static func restore_engine_errors(test: GutTest, previous: int) -> void:
	test.gut.error_tracker.treat_engine_errors_as = previous
