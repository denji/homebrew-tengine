# Tengine Homebrew Tap

[Tengine](https://github.com/alibaba/tengine) has full compatibility with nginx-1.4.x, but it also has support for Dynamic Module Loading Support (DSO) to compile it using [dso_tools](http://tengine.taobao.org/document/dso.html).  

Default tengine is limited to 256 loadable shared modules.

## Installation

Then, run the following in your command-line:

    brew tap denji/tengine

## Usage

**Note**: For a list of available configuration options run:

    brew options tengine
    brew info tengine

Once the tap is installed, you can install `tengine` with optional additional functionality and modules.

    brew install tengine --with-spdy
    brew install tengine-upload-module


## What about conflicts?

You are free to install this version alongside a current install of Nginx from `Homebrew/homebrew` if you wish. However, they cannot be linked at the same time. To switch between them use brew's built in linking system. The configuration files are moved from the folder `etc/nginx` `etc/tengine`.

    brew unlink nginx
    brew unlink nginx-full
    brew link tengine
