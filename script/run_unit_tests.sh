#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

BUILD_DIR=".build/unit-tests"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

APP_SOURCES=(
    "Sources/WorkLog/Models/AppSection.swift"
    "Sources/WorkLog/Models/AppTheme.swift"
    "Sources/WorkLog/Models/AppData.swift"
    "Sources/WorkLog/Models/WorkExperience.swift"
    "Sources/WorkLog/Models/InterviewOpportunity.swift"
    "Sources/WorkLog/Models/DocumentRecord.swift"
    "Sources/WorkLog/Support/JSONCoders.swift"
    "Sources/WorkLog/Support/DateFormatters.swift"
    "Sources/WorkLog/Support/StringHelpers.swift"
    "Sources/WorkLog/Support/AppRuntimeConfiguration.swift"
    "Sources/WorkLog/Support/DemoDataFactory.swift"
    "Sources/WorkLog/Services/DataPersistenceService.swift"
    "Sources/WorkLog/Services/DocumentStorageService.swift"
    "Sources/WorkLog/Services/BackupService.swift"
    "Sources/WorkLog/Services/TaskImportService.swift"
    "Sources/WorkLog/Services/CalendarInterviewImportService.swift"
    "Sources/WorkLog/Stores/AppStore.swift"
)

TEST_SOURCES=(
    "Tests/WorkLogTests/BackupAndPersistenceTests.swift"
    "Tests/WorkLogTests/InterviewAndDocumentLogicTests.swift"
)

swiftc \
    -swift-version 5 \
    -parse-as-library \
    -enable-testing \
    -module-name WorkLog \
    -emit-library \
    -emit-module \
    -emit-module-path "$BUILD_DIR/WorkLog.swiftmodule" \
    -o "$BUILD_DIR/libWorkLog.dylib" \
    "${APP_SOURCES[@]}"

cat > "$BUILD_DIR/XCTestShim.swift" <<'SWIFT'
@_exported import Foundation

open class XCTestCase {
    public init() {}
}

public enum XCTestFailureRecorder {
    public private(set) static var failures: [String] = []

    public static func record(_ message: String, file: StaticString, line: UInt) {
        failures.append("\(file):\(line): \(message)")
    }
}

private func describe(_ value: Any?) -> String {
    String(describing: value)
}

private struct XCTUnwrapError: Error {}

public func XCTFail(
    _ message: String = "",
    file: StaticString = #filePath,
    line: UInt = #line
) {
    XCTestFailureRecorder.record(message.isEmpty ? "failed" : message, file: file, line: line)
}

public func XCTAssertTrue(
    _ expression: @autoclosure () throws -> Bool,
    _ message: @autoclosure () -> String = "",
    file: StaticString = #filePath,
    line: UInt = #line
) {
    do {
        if try !expression() {
            XCTFail(message().isEmpty ? "expected true" : message(), file: file, line: line)
        }
    } catch {
        XCTFail("unexpected error: \(error)", file: file, line: line)
    }
}

public func XCTAssertFalse(
    _ expression: @autoclosure () throws -> Bool,
    _ message: @autoclosure () -> String = "",
    file: StaticString = #filePath,
    line: UInt = #line
) {
    do {
        if try expression() {
            XCTFail(message().isEmpty ? "expected false" : message(), file: file, line: line)
        }
    } catch {
        XCTFail("unexpected error: \(error)", file: file, line: line)
    }
}

public func XCTAssertEqual<T: Equatable>(
    _ expression1: @autoclosure () throws -> T,
    _ expression2: @autoclosure () throws -> T,
    _ message: @autoclosure () -> String = "",
    file: StaticString = #filePath,
    line: UInt = #line
) {
    do {
        let value1 = try expression1()
        let value2 = try expression2()
        if value1 != value2 {
            let defaultMessage = "expected \(describe(value1)) to equal \(describe(value2))"
            XCTFail(message().isEmpty ? defaultMessage : message(), file: file, line: line)
        }
    } catch {
        XCTFail("unexpected error: \(error)", file: file, line: line)
    }
}

public func XCTAssertEqual<T: Equatable>(
    _ expression1: @autoclosure () throws -> T?,
    _ expression2: @autoclosure () throws -> T?,
    _ message: @autoclosure () -> String = "",
    file: StaticString = #filePath,
    line: UInt = #line
) {
    do {
        let value1 = try expression1()
        let value2 = try expression2()
        if value1 != value2 {
            let defaultMessage = "expected \(describe(value1)) to equal \(describe(value2))"
            XCTFail(message().isEmpty ? defaultMessage : message(), file: file, line: line)
        }
    } catch {
        XCTFail("unexpected error: \(error)", file: file, line: line)
    }
}

public func XCTAssertNotEqual<T: Equatable>(
    _ expression1: @autoclosure () throws -> T,
    _ expression2: @autoclosure () throws -> T,
    _ message: @autoclosure () -> String = "",
    file: StaticString = #filePath,
    line: UInt = #line
) {
    do {
        let value1 = try expression1()
        let value2 = try expression2()
        if value1 == value2 {
            let defaultMessage = "expected \(describe(value1)) to not equal \(describe(value2))"
            XCTFail(message().isEmpty ? defaultMessage : message(), file: file, line: line)
        }
    } catch {
        XCTFail("unexpected error: \(error)", file: file, line: line)
    }
}

public func XCTAssertNotNil<T>(
    _ expression: @autoclosure () throws -> T?,
    _ message: @autoclosure () -> String = "",
    file: StaticString = #filePath,
    line: UInt = #line
) {
    do {
        if try expression() == nil {
            XCTFail(message().isEmpty ? "expected non-nil" : message(), file: file, line: line)
        }
    } catch {
        XCTFail("unexpected error: \(error)", file: file, line: line)
    }
}

public func XCTAssertThrowsError<T>(
    _ expression: @autoclosure () throws -> T,
    _ message: @autoclosure () -> String = "",
    file: StaticString = #filePath,
    line: UInt = #line,
    _ errorHandler: (Error) -> Void = { _ in }
) {
    do {
        _ = try expression()
        XCTFail(message().isEmpty ? "expected thrown error" : message(), file: file, line: line)
    } catch {
        errorHandler(error)
    }
}

public func XCTUnwrap<T>(
    _ expression: @autoclosure () throws -> T?,
    _ message: @autoclosure () -> String = "",
    file: StaticString = #filePath,
    line: UInt = #line
) throws -> T {
    let value = try expression()
    guard let unwrapped = value else {
        XCTFail(message().isEmpty ? "expected non-nil" : message(), file: file, line: line)
        throw XCTUnwrapError()
    }
    return unwrapped
}
SWIFT

swiftc \
    -swift-version 5 \
    -parse-as-library \
    -module-name XCTest \
    -emit-library \
    -emit-module \
    -emit-module-path "$BUILD_DIR/XCTest.swiftmodule" \
    -o "$BUILD_DIR/libXCTest.dylib" \
    "$BUILD_DIR/XCTestShim.swift"

TEST_LIST="$BUILD_DIR/TestList.txt"
awk '
    /^final class .*: XCTestCase/ {
        className = $3
        sub(/:.*/, "", className)
    }
    /^[[:space:]]*@MainActor/ {
        mainActor = 1
        next
    }
    /^[[:space:]]*func test[A-Za-z0-9_]+[[:space:]]*\(/ {
        method = $0
        sub(/^[[:space:]]*func[[:space:]]+/, "", method)
        sub(/[[:space:]]*\(.*/, "", method)
        throws = ($0 ~ /throws/) ? 1 : 0
        print className "|" method "|" throws "|" mainActor
        mainActor = 0
    }
' "${TEST_SOURCES[@]}" > "$TEST_LIST"

RUNNER="$BUILD_DIR/GeneratedRunner.swift"
cat > "$RUNNER" <<'SWIFT'
import Darwin
import XCTest

@main
struct WorkLogUnitTestRunner {
    private static var passed = 0
    private static var failed = 0

    private static func run(_ name: String, _ body: () throws -> Void) {
        let before = XCTestFailureRecorder.failures.count
        do {
            try body()
        } catch {
            XCTFail("Unexpected thrown error in \(name): \(error)")
        }

        let after = XCTestFailureRecorder.failures.count
        if after == before {
            passed += 1
            print("PASS \(name)")
        } else {
            failed += 1
            print("FAIL \(name)")
            for failure in XCTestFailureRecorder.failures[before..<after] {
                print("  \(failure)")
            }
        }
    }

    @MainActor
    private static func runOnMainActor(_ name: String, _ body: () throws -> Void) async {
        run(name, body)
    }

    static func main() async {
SWIFT

while IFS='|' read -r class_name method_name throws_flag main_actor_flag; do
    if [[ "$throws_flag" == "1" ]]; then
        call="try ${class_name}().${method_name}()"
    else
        call="${class_name}().${method_name}()"
    fi

    if [[ "$main_actor_flag" == "1" ]]; then
        printf '        await runOnMainActor("%s.%s") { %s }\n' "$class_name" "$method_name" "$call" >> "$RUNNER"
    else
        printf '        run("%s.%s") { %s }\n' "$class_name" "$method_name" "$call" >> "$RUNNER"
    fi
done < "$TEST_LIST"

cat >> "$RUNNER" <<'SWIFT'

        print("Unit test summary: \(passed) passed, \(failed) failed")
        if failed > 0 { exit(1) }
    }
}
SWIFT

swiftc \
    -swift-version 5 \
    -I "$BUILD_DIR" \
    -L "$BUILD_DIR" \
    -lWorkLog \
    -lXCTest \
    -Xlinker -rpath \
    -Xlinker "$BUILD_DIR" \
    "${TEST_SOURCES[@]}" \
    "$RUNNER" \
    -o "$BUILD_DIR/WorkLogUnitTests"

DYLD_LIBRARY_PATH="$BUILD_DIR" "$BUILD_DIR/WorkLogUnitTests"
