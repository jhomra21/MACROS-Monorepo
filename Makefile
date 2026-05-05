PROJECT := cal-macro-tracker.xcodeproj
SCHEME := cal-macro-tracker
DESTINATION := generic/platform=iOS Simulator
QUALITY_DIR := tools/quality

.PHONY: quality quality-build quality-format-check format quality-dead quality-dup quality-debt quality-deps quality-n1 quality-secrets quality-storekit

quality: quality-build quality-format-check quality-dead quality-dup quality-debt quality-deps quality-n1 quality-secrets quality-storekit

quality-build:
	xcodebuild -project "$(PROJECT)" -scheme "$(SCHEME)" -configuration Debug -destination '$(DESTINATION)' build

quality-format-check:
	sh "$(QUALITY_DIR)/run_swift_format.sh" --config ".swift-format" --mode lint --target "cal-macro-tracker"

format:
	sh "$(QUALITY_DIR)/run_swift_format.sh" --config ".swift-format" --mode format --target "cal-macro-tracker"

quality-dead:
	sh "$(QUALITY_DIR)/run_periphery.sh" --config ".periphery.yml" --destination "$(DESTINATION)"

quality-dup:
	sh "$(QUALITY_DIR)/duplicate_blocks.sh" --root "cal-macro-tracker" --min-lines 12

quality-debt:
	sh "$(QUALITY_DIR)/tech_debt.sh" --root "cal-macro-tracker" --max-lines 300 --max-function-lines 80

quality-deps:
	sh "$(QUALITY_DIR)/dependency_inventory.sh" --project "$(PROJECT)/project.pbxproj"

quality-n1:
	sh "$(QUALITY_DIR)/nplusone_smoke.sh" --root "cal-macro-tracker"

quality-secrets:
	sh "$(QUALITY_DIR)/test_validate_example_env_secrets.sh"
	sh "$(QUALITY_DIR)/validate_example_env_secrets.sh" --root "."

quality-storekit:
	python3 "$(QUALITY_DIR)/validate_storekit_config.py"
