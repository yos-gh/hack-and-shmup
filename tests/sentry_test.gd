extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	SentrySDK.add_breadcrumb(SentryBreadcrumb.create("Manual SDK integration verification"))
	SentrySDK.capture_message("HACK & SHMUP: SDK integration verification 2026-09-05")
	SentrySDK.logger.info("Sentry structured logs verification 2026-09-05")
	await create_timer(3.0).timeout
	print("PASS: Sentry verification event and structured log submitted")
	quit()
