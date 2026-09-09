extends SceneTree

func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	# Local binding/configuration smoke only. Never submit events in regression runs.
	var ready := is_instance_valid(SentrySDK) and SentrySDK.has_method("capture_message")
	var configured := not str(ProjectSettings.get_setting("sentry/options/dsn", "")).is_empty()
	if not ready or not configured:
		push_error("FAIL: Sentry binding or configuration is missing")
		quit(1)
		return
	print("PASS: Sentry binding and configuration available; no verification event sent")
	quit()
