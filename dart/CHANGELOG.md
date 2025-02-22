# Beta

## 0.0.0
- Initial release

### 0.0.1
- Improved documentation

## 0.1.0
- Added automatic session renewal
- Removed the requirement to have manual session renewal
- Added `verifyLogin` function to verify a login
- Improved functionality and error handling

### 0.1.1
- Improved documentation

### 0.1.2
- Removed dart:ui library in favor of using dart:io to get region, now allowing all Dart programs to use the dexcom package instead of just Flutter programs
- Removed logging using print() in favor of Exceptions
- Improved documentation

### 0.1.3
- Added web support
- Improved code comments

### 0.1.4
- Removed uuid dependency requirement
- Changed website URL and repository URL
- Improved documentation
- Improved code comments

### 0.1.5
- Fixed web support issue
- Improved code comments

### 0.1.6
- Improved documentation

### 0.1.7
- Included a check for Internet
- Improved error handling

### 0.1.8
- Improved documentation

### 0.1.9
- Completely rewrote example as a fully functional Flutter app with detailed examples and processes
- Updated Important Information in README.md

### 0.1.10
- Updated Dexcom class to not set username and password as finals, and add an optional region parameter
- Improved documentation
- Updated dependencies

## 0.2.0 - Breaking Changes
- New DexcomStreamProvider class, which makes it easy to listen to a Dexcom object
- New DexcomAppIds class, which holds app IDs (not required, yet)
- Example is now in Dart instead of Flutter
- Other small (but potentially breaking) changes:
    - A lot of methods in the Dexcom class were made private
    - The constructor is now named ((parameter: value) instead of just (value))
- A lot of other small-to-medium changes