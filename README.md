# SimRa iOS App

This project is part of the SimRa research project which includes the following subprojects:
- [sirma-android](https://github.com/simra-project/simra-android/): The SimRa app for Android.
- [simra-ios](https://github.com/simra-project/simra-ios): The SimRa app for iOS.
- [backend](https://github.com/simra-project/backend): The SimRa backend software.
- [dataset](https://github.com/simra-project/dataset): Result data from the SimRa project.
- [screenshots](https://github.com/simra-project/screenshots): Screenshots of both the iOS and Android app.
- [SimRa-Visualization](https://github.com/simra-project/SimRa-Visualization): Web application for visualizing the dataset.

In this project, we collect – with a strong focus on data protection and privacy – data on such near crashes to identify when and where bicyclists are especially at risk. We also aim to identify the main routes of bicycle traffic in Berlin. To obtain such data, we have developed a smartphone app that uses GPS information to track routes of bicyclists and the built-in acceleration sensors to pre-categorize near crashes. After their trip, users are asked to annotate and upload the collected data, pseudonymized per trip.
For more information see [our website](https://www.digital-future.berlin/en/research/projects/simra/).

## LICENSE

 Markup : * SimRa uses [TTRangeSlider](https://github.com/TomThorpe/TTRangeSlider) by Tom Thorpe available under the MIT license.
          * SimRa uses [SSZipArchive](https://github.com/ZipArchive/ZipArchive) by ZipArchive under the MIT license. 
          * SimRa uses [TTGSnackbar](https://github.com/zekunyan/TTGSnackbar) by Zekunyan under the MIT license. 
          * SimRa uses [Loaf](https://github.com/schmidyy/Loaf) by Mat Schmid under the MIT license. 


## Instructions
Build with Xcode 10.2 for iOS >= 11.0
Packages are integrated with the help of [Cocoapods](https://cocoapods.org)

### How to Build

The suffix used in the `clientHash` to protect the upload is not part of the source code. 
To compile the project:

- copy the file `Hash-Suffix.h.sample` to `Hash-Suffix.h`
- replace the sample suffix #define HASH_SUFFIX @"mcc_simra"` with the suffix provided from the backend operator
- compile

Always open `SimRa.xcworkspace` with Xcode, not `SimRa.xcodeproj` to include Cocoapods.


### Features

- Internationalization (Base (Developer), en - English and de - Deutsch languages are available and are selected
  by the iPhone's language settings.
  
  To modify, edit the following files in the `en.lproj` or `de.lproj` directories
  - Localizable.strings - for the texts set programatically
  - Main.strings - for the interface builder texts
  - constants.plist - for the text used in drop down lists
