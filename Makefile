PROJECT := cal-macro-tracker.xcodeproj
SCHEME := cal-macro-tracker
DESTINATION := platform=macOS
QUALITY_DIR := tools/quality

.PHONY: quality quality-build quality-lint quality-format-check format quality-dead quality-dup quality-debt quality-deps quality-n1

quality: quality-build quality-lint quality-format-check quality-dead quality-dup quality-debt quality-deps quality-n1

quality-build:
	xcodebuild -project "$(PROJECT)" -scheme "$(SCHEME)" -configuration Debug -destination '$(DESTINATION)' build

quality-lint:
	sh "$(QUALITY_DIR)/run_swiftlint.sh" --config ".swiftlint.yml"

quality-format-check:
	sh "$(QUALITY_DIR)/run_swiftformat.sh" --config ".swiftformat" --mode lint --target "cal-macro-tracker"

format:
	sh "$(QUALITY_DIR)/run_swiftformat.sh" --config ".swiftformat" --mode format --target "cal-macro-tracker"

quality-dead:
	sh "$(QUALITY_DIR)/run_periphery.sh" --config ".periphery.yml"

quality-dup:
	sh "$(QUALITY_DIR)/duplicate_blocks.sh" --root "cal-macro-tracker" --min-lines 12

quality-debt:
	sh "$(QUALITY_DIR)/tech_debt.sh" --root "cal-macro-tracker" --max-lines 300 --max-function-lines 80

quality-deps:
	sh "$(QUALITY_DIR)/dependency_inventory.sh" --project "$(PROJECT)/project.pbxproj"

quality-n1:
	sh "$(QUALITY_DIR)/nplusone_smoke.sh" --root "cal-macro-tracker"
