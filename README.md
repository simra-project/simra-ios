# SimRa iOS App

Build with Xcode 10.2 for iOS >= 11.0
Packages are integrated with the help of [Cocoapods](https://cocoapods.org)

## How to Build

The suffix used in the `clientHash` to protect the upload is not part of the source code. 
To compile the project:

- copy the file `Hash-Suffix.h.sample` to `Hash-Suffix.h`
- replace the sample suffix #define HASH_SUFFIX @"mcc_simra"` with the suffix provided from the backend operator
- compile

Always open `SimRa.xcworkspace` with Xcode, not `SimRa.xcodeproj` to include Cocoapods.


## Features

- Internationalization (Base (Developer), en - English and de - Deutsch languages are available and are selected
  by the iPhone's language settings.
  
  To modify, edit the following files in the `en.lproj` or `de.lproj` directories
  - Localizable.strings - for the texts set programatically
  - Main.strings - for the interface builder texts
  - constants.plist - for the text used in drop down lists

- ...

## LICENSE

SimRa uses [TTRangeSlider](https://github.com/TomThorpe/TTRangeSlider) by Tom Thorpe available under the MIT license.
