# rust-xtensa-toolchain

A dev environment container that has pre-release versions of Rust for Xtensa devices (specifically the ESP32).

Credit goes to @lexxir, @MabezDev, and the folks over at Espressif developing llvm-xtensa.

This includes ESP-IDF and is designed to be used with something like [this](https://github.com/lexxvir/esp32-hello). Since this uses the latest version of llvm-xtensa, some of the flags in `.cargo/config` are slightly different; more information soon.