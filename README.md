# streamZ
A simple video streaming application made with _Dart_, _JS_, _HTML_, _CSS_ & :heart: 

Show some :heart: by putting :star:

_Recently I wrote an article, explaining how to deploy it using systemd in LAN, which can be found [here](http://itzmeanjan.in/blog/post_1)._

## what does it do ?
- A streaming service, intended to run in small network(s) _( may be in your home network )_, which lets you stream movies to any device present in that network & having a standard browser installed _( yeah HTML5 support required )_
- Backend, fully written in _Dart_, leveraging power of _dart:io_ & _dart:isolate_
- Frontend, powered by _HTML_, _CSS_ & last but not least _Javascript_ _( yeah not using any UI framework )_
- Audio-Video playing is done using HTML5 **\<video>** element, which can play _mp4_ & _webm_ video(s) generally
## how can I use it ?
- If you're on _Linux_, then I've already compiled **streamZ** into an executable binary _( using dart2native compiler )_, which can be simply run on any Linux Machine, cause that executable binary is one self-sufficient one _( but not yet platform-agnostic, which will change is near future )_.
- Then download [_this_](https://github.com/itzmeanjan/streamZ/releases/download/v1.0.1/streamZ.zip) compressed file, and unzip it into a suitable location on your machine.
- You'll get a directory tree like below
```shell script
$ wget https://github.com/itzmeanjan/streamZ/releases/download/v1.0.1/streamZ.zip # consider downloading zip, using wget from terminal
$ cd
$ unzip streamZ.zip # unzipping it
$ cd streamZ # getting into actual directory
$ tree -h
.
├── [4.0K]  final
│   └── [7.8M]  streamZ
└── [4.0K]  frontend
    ├── [4.0K]  images
    │   └── [ 318]  favicon.ico
    ├── [4.0K]  pages
    │   └── [1.0K]  index.html
    ├── [4.0K]  scripts
    │   └── [9.7K]  index.js
    └── [4.0K]  styles
        └── [2.0K]  index.css

6 directories, 5 files
```
- Now get into `./final` directory & run executable binary, which will start a media streaming server on _http://0.0.0.0:8000_
```shell script
$ cd final
$ ./streamZ # running movie steaming server
[+]streamZ_v1.0.0 listening ( streamZ0 ) ...

[+]streamZ_v1.0.0 listening ( streamZ1 ) ...

```
- To check, open browser from same machine & type _http://localhost:8000_ into address bar, you'll get a list of all movies present under _~/Videos/_ directory, which is default video storing directory on _Linux_ running machines.
- You can also access this streaming service by opening _http://x.x.x.x:8000/_,on any device's browser, present in LAN
- Where `x.x.x.x` is nothing but Local IP Address of machine, running **streamZ**
---
- If you want to dig deeper, simply fork this repo & clone it in you machine
- Make sure you've installed _Dart SDK_ & you're on _*nix_ platform
- Because I gonna use _systemd.service_ to keep this streaming service alive in background, always, even after system restarts it'll auto start itself
- You need to make sure, you've _~/Videos/_ directory present on your system, cause we'll read from that directory _( every 30 minutes )_, to ensure all _mp4_ & _webm_ videos, present in aforementioned directory, are listed in movie playlist
- If you're having a lot of traffic, consider using multiple Isolates to handle traffic efficiently. Just update `int count = 2;` on line 100 of `./bin/main.dart` to whatever value you intend to use, that many Isolate(s) will be created on boot, they'll distributedly handle whole traffic coming in.
- I've also written one systemd unit file, which can be used for deploying **streamZ**, so that it'll keep running always _( autostart after failure & system boot )_
- Consider using so, by modifying this systemd unit [file](./systemd/streamZ.service)
## how does it look like ?
![screenCapture_1](screencaptures/screenCapture_1.png)

![screenCapture_2](screencaptures/screenCapture_2.png)

![screenCapture_3](screencaptures/screenCapture_3.png)

**Feel free to check source code to dig deeper _( it's pretty well documented )_**

Hope it helps ... :wink:
