# Version 0 - Beta

## 0.0.0 - 11/14/24
- Initial release

### 0.0.1 - 11/14/24
- Improved documentation

## 0.1.0 - 11/15/24
- Added automatic session renewal
- Removed the requirement to have manual session renewal
- Added `verifyLogin` function to verify a login
- Improved functionality and error handling

### 0.1.1 - 11/15/24
- Improved documentation

### 0.1.2 - 11/15/24
- Removed dart:ui library in favor of using dart:io to get region, now allowing all Dart programs to use the dexcom package instead of just Flutter programs
- Removed logging using print() in favor of Exceptions
- Improved documentation

### 0.1.3 - 11/15/24
- Added web support
- Improved code comments

### 0.1.4 - 11/15/24
- Removed uuid dependency requirement
- Changed website URL and repository URL
- Improved documentation
- Improved code comments

### 0.1.5 - 11/15/24
- Fixed web support issue
- Improved code comments

### 0.1.6 - 11/15/24
- Improved documentation

### 0.1.7 - 11/2/24
- Included a check for Internet
- Improved error handling

### 0.1.8 - 11/29/24
- Improved documentation

### 0.1.9 - 12/14/24
- Completely rewrote example as a fully functional Flutter app with detailed examples and processes
- Updated Important Information in README.md

### 0.1.10 - 2/21/25
- Updated Dexcom class to not set username and password as finals, and add an optional region parameter
- Improved documentation
- Updated dependencies

# Version 1 - Release

## 1.0.0 - Breaking Changes - 2/28/25
- New DexcomStreamProvider class, which makes it easy to listen to a Dexcom object
- New DexcomAppIds class, which holds app IDs
- Example is now in Dart instead of Flutter
- Other small (but potentially breaking) changes:
    - A lot of methods in the Dexcom class were made private
    - The constructor now uses named parameters ((parameter: value) instead of just (value))
    - 'verifyLogin' is now 'verify'
- A lot of other small-to-medium changes

### 1.0.1 - 2/28/25
- New errors: DexcomAuthorizationException and DexcomGlucoseRetrievalException. They are called on authorization failure and glucose retrieval failure.
- Improved documentation

### 1.0.2 - 7/29/25 - Breaking Changes
- `verify()` now returns a `DexcomVerificationResult` instead of a `Map`
- Improved typing
- Improved documentation