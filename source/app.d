import core.thread;

import std.conv;
import std.datetime;
import std.string;
import std.stdio;

import blink1.clib;
import blink1;

void main()
{
	writeln("Edit source/app.d to start your project.");
	//blink1_device * dev = blink1_open();
	//blink1_setRGB(dev, 255, 255, 0);
	Blink1Device dev = Blink1Device.open();
	/*dev.defaultDuration = msecs(250);
	writeln("Connected device: %s".format(dev.getFwVersion()));
	dev.fadeToRGB(255, 0, 255, dur!"seconds"(1));
	Thread.sleep(dur!"seconds"(1));
	dev.fadeToRGB(0, 0, 255, seconds(1));
	Thread.sleep(dur!"seconds"(1));
	dev.fadeToRGB(0, 0, 0, seconds(1), Blink1Device.LED.ONE);
	Thread.sleep(seconds(1));
	dev.fadeToRGB(0, 0, 0, seconds(1), Blink1Device.LED.TWO);
	Thread.sleep(seconds(2));

	for(int i = 0; i < 3; i++) {
		dev.fadeToRGB(0, 255, 0);
		Thread.sleep(dev.defaultDuration);
		dev.fadeToRGB(0, 0, 0);
		Thread.sleep(dev.defaultDuration);
	}
	dev.fadeToRGB(0, 255, 0);
	Thread.sleep(seconds(10));
	dev.fadeToRGB(0, 0, 0);*/
	/*dev.enableServerDown(seconds(5), true);
	for (int i = 0; i < 5; i++) {
		Thread.sleep(seconds(4));
		dev.pokeServerDown();
	}*/
	/*dev.writeNote(0, "Note0: foo bar this is a very, very, very, very long test note".representation);
	ubyte[] note = dev.readNote(0);
	writeln(note.assumeUTF);
	dev.writeNote(0, "Note0: This is a test note".representation);*/
	dev.blocking = true;
	dev.fadeToRGB(255, 0, 0);
	dev.fadeToRGB(0, 0, 255);
}
