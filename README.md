# D wrapper for blink1-lib

`dub add blink1-d`

## C api
The C api can be directly used by importing `blink1.clib1`. This should be the same as the C api.

Example:
```d
import blink1.clib;

blink1_device *dev = blink1_open();
blink1_setRGB(dev, 176, 56, 49);

ubyte[] noteBuffer = new ubyte[50];
ubyte *noteBufferPtr = noteBuffer.ptr;
blink1_readNote(m_device, 0, &noteBufferPtr);

writeln(noteBuffer.assumeUTF);
```

## D wrapper

Some examples:

```d
import blink1;

import core.thread;

import std.datetime;
import std.stdio;

// Opening the first device.
Blink1Device led = Blink1Device.open();

// Setting a color
led.setRGB(176, 56, 49);
Thread.sleep(seconds(1));

// fading to a color a few times.
for(int i = 0; i < 3; i++) {
	led.fadeToRGB(0, 255, 0);
	// led.defaultDuration contains the default fade animation duration.
	Thread.sleep(led.defaultDuration);
	led.fadeToRGB(0, 0, 0);
	Thread.sleep(led.defaultDuration);
}
// But it can be overridden.
led.defaultDuration = seconds(2);
led.fadeToRGB(0, 255, 0);
Thread.sleep(dev.defaultDuration);

// Or be set for only one led
led.fadeToRGB(0, 0, 0, msecs(200));
Thread.sleep(msecs(200));

// Does the Thread.sleep get tiresome?
led.blocking = true;
led.fadeToRGB(255, 0, 0);
led.fadeToRGB(0, 255, 0);

// Or only change one LED!
led.fadeToRGB(0, 0, 0, seconds(1), Blink1Device.LED.TWO);

// Enable the serverDown mode
led.enableServerDown(seconds(5), true, 0, 6);
Thread.sleep(seconds(4));
led.pokeServerDown();
Thread.sleep(seconds(10));
led.disableServerDown();

// Leave a note behind.
led.writeNote(0, "You can never have too many red cabbages!".representation);
// And read it back.
writeln(led.readNote(0).assumeUTF);
```

## License
[blink1-lib](https://github.com/todbot/blink1-tool/) is licensed under the CC-BY-SA 4.0. Since that
license isn't really fit for code, I chose to license this project under the GPLv3.0, which is
compatible with CC-BY-SA 4.0, and makes more sense for software.
