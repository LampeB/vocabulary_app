# Testing Guide for VocabApp

This document describes the testing strategy and how to run tests for the VocabApp.

## Test Structure

The app uses Flutter's comprehensive testing framework with three types of tests:

### 1. **Unit Tests** (test/)
Test individual functions and classes in isolation.

**Location**: `test/`

**Example**: [test/utils/answer_validator_test.dart](test/utils/answer_validator_test.dart)

**What we test:**
- Answer validation logic
- String similarity matching
- Register compatibility
- Accent handling
- Quality feedback

### 2. **Widget Tests** (test/)
Test UI components and their interactions.

**Location**: `test/widgets/` or `test/screens/`

**What to test:**
- Individual widgets render correctly
- User interactions work as expected
- State changes update the UI
- Navigation between screens

### 3. **Integration Tests** (integration_test/)
Test complete user flows end-to-end.

**Location**: `integration_test/`

**Example**: [integration_test/app_test.dart](integration_test/app_test.dart)

**What we test:**
- Complete user journeys
- App launches correctly
- Creating lists and words
- Taking quizzes
- Navigation flows
- Data persistence

---

## Running Tests

### Run All Unit Tests
```bash
cd vocabulary_app
flutter test
```

### Run Specific Test File
```bash
flutter test test/utils/answer_validator_test.dart
```

### Run Tests with Coverage
```bash
flutter test --coverage
```

This generates a coverage report in `coverage/lcov.info`.

To view coverage in HTML:
```bash
# Install lcov (if not installed)
# On Windows with Chocolatey: choco install lcov
# On Mac: brew install lcov
# On Linux: sudo apt-get install lcov

# Generate HTML report
genhtml coverage/lcov.info -o coverage/html

# Open in browser
start coverage/html/index.html  # Windows
open coverage/html/index.html   # Mac
xdg-open coverage/html/index.html  # Linux
```

### Run Integration Tests

**On Android Emulator:**
```bash
# Make sure emulator is running
flutter emulators --launch <emulator_id>

# Run integration tests
flutter test integration_test/app_test.dart -d emulator-5554
```

**On Windows:**
```bash
flutter test integration_test/app_test.dart -d windows
```

**On a real device:**
```bash
flutter devices  # Find your device ID
flutter test integration_test/app_test.dart -d <device_id>
```

---

## Test Organization

```
vocabulary_app/
├── test/
│   ├── utils/
│   │   ├── answer_validator_test.dart  ✅ (22 tests)
│   │   └── srs_algorithm_test.dart     (TODO)
│   ├── models/
│   │   └── (model tests)               (TODO)
│   ├── services/
│   │   └── (service tests)             (TODO)
│   └── widget_test.dart
├── integration_test/
│   └── app_test.dart                    ✅ (7 integration tests)
└── TESTING.md                           (this file)
```

---

## Writing New Tests

### Unit Test Example

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:vocabulary_app/utils/my_utility.dart';

void main() {
  group('MyUtility', () {
    test('does something correctly', () {
      final result = MyUtility.doSomething(input);

      expect(result, expectedValue);
      expect(result, isNotNull);
      expect(result.length, greaterThan(0));
    });

    test('handles edge cases', () {
      expect(() => MyUtility.doSomething(null), throwsException);
    });
  });
}
```

### Widget Test Example

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocabulary_app/screens/my_screen.dart';

void main() {
  testWidgets('MyScreen displays correctly', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: MyScreen()),
    );

    expect(find.text('Expected Text'), findsOneWidget);
    expect(find.byType(ElevatedButton), findsOneWidget);

    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();

    expect(find.text('After Click'), findsOneWidget);
  });
}
```

### Integration Test Example

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:vocabulary_app/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Complete user flow', (tester) async {
    app.main();
    await tester.pumpAndSettle();

    // Interact with app
    await tester.tap(find.text('Button'));
    await tester.pumpAndSettle();

    // Verify result
    expect(find.text('Success'), findsOneWidget);
  });
}
```

---

## Test Coverage Goals

| Component | Target Coverage |
|-----------|----------------|
| Utils | 90%+ |
| Models | 80%+ |
| Services | 80%+ |
| Screens | 60%+ |
| Overall | 70%+ |

---

## Continuous Integration

For CI/CD pipelines (GitHub Actions, GitLab CI, etc.):

```yaml
# Example GitHub Actions workflow
name: Tests
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - uses: subosito/flutter-action@v2
      - run: flutter pub get
      - run: flutter test --coverage
      - run: flutter test integration_test/app_test.dart -d linux
```

---

## Test Best Practices

1. **Write tests first** (TDD) when possible
2. **Keep tests isolated** - no dependencies between tests
3. **Use descriptive test names** - `test('validates correct answer with typo tolerance')`
4. **Test edge cases** - empty inputs, null values, extreme numbers
5. **Mock external dependencies** - databases, APIs, file system
6. **Keep tests fast** - unit tests should run in milliseconds
7. **Update tests when code changes** - keep them in sync
8. **Aim for high coverage** - but focus on critical paths first

---

## Debugging Tests

### Run tests in debug mode:
```bash
flutter test --start-paused
```

Then attach the debugger in VS Code or Android Studio.

### Print debugging:
```dart
test('my test', () {
  print('Debug value: $someValue');
  debugPrint('Another debug message');
});
```

### Visual debugging for widget tests:
```dart
testWidgets('my widget test', (tester) async {
  await tester.pumpWidget(MyWidget());

  // Take a screenshot
  await expectLater(
    find.byType(MyWidget),
    matchesGoldenFile('golden/my_widget.png'),
  );
});
```

---

## Current Test Results

### Unit Tests
✅ **Answer Validator**: 22/22 tests passing
- Exact matches
- Similarity matching
- Multiple expected answers
- Empty answers
- Quality feedback
- Register compatibility
- Variant matching
- Accent handling

### Integration Tests
✅ **App Integration**: 7/7 tests passing
- App launch
- List creation
- Navigation
- Quiz flow
- Theme handling

---

## TODO: Tests to Add

- [ ] SRS Algorithm unit tests
- [ ] Database service tests (with mocks)
- [ ] Concept repository tests
- [ ] Vocabulary list repository tests
- [ ] Audio service tests
- [ ] Home screen widget tests
- [ ] Quiz screen widget tests
- [ ] Settings screen widget tests
- [ ] Complete quiz flow integration test
- [ ] Audio playback integration test

---

## Questions?

For issues or questions about testing, please refer to:
- [Flutter Testing Documentation](https://docs.flutter.dev/testing)
- [Integration Testing Guide](https://docs.flutter.dev/testing/integration-tests)
