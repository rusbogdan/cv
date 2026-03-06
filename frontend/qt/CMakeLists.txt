
cmake_minimum_required(VERSION 3.21)
project(cv_wasm LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)

find_package(Qt6 REQUIRED COMPONENTS Quick)

qt_add_executable(cv_wasm main.cpp)
set_target_properties(cv_wasm PROPERTIES AUTOMOC ON)

qt_add_qml_module(cv_wasm
 URI Cv
 VERSION 1.0
 QML_FILES
  qml/Main.qml
  qml/CvPage.qml
  qml/UnderTheHood.qml
  qml/IntroPage.qml
 RESOURCES
  fonts/Inter_18pt-Regular.ttf
  fonts/Inter_18pt-Bold.ttf
  fonts/Inter_18pt-Italic.ttf
  fonts/Inter_18pt-Thin.ttf
  fonts/Inter_18pt-BoldItalic.ttf
  fonts/WorkSans-ThinItalic.ttf
  fonts/WorkSans-ExtraBold.ttf
  fonts/DMSans_18pt-ExtraLight.ttf
  fonts/DMSans_18pt-BlackItalic.ttf
  fonts/Nunito-ExtraLightItalic.ttf
  fonts/Nunito-Black.ttf
  fonts/Sora-Light.ttf
  fonts/SpaceGrotesk-Regular.ttf
  fonts/Outfit-Medium.ttf
  fonts/RobotoMono-Bold.ttf
)

target_link_libraries(cv_wasm PRIVATE Qt6::Quick)
