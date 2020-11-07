module blink1;

import core.thread;

import std.algorithm;
import std.datetime;
import std.exception;
import std.string;

import blink1.clib;


version(withColor) {
	import std.experimental.color;
}

class Blink1NotFoundException : Exception {
	mixin basicExceptionCtors;
}

class UnsupportedOperationException : Exception {
	mixin basicExceptionCtors;
}

alias Blink1Type = blink1Type_t;

class Blink1Device {

	enum LED {
		ALL = 0,
		ONE = 1,
		TWO = 2
	}

	public static immutable MAX_NOTES = 10;
	public static immutable MAX_NOTE_SIZE = blink1_note_size;

	// Our "handle" to the blink led.
	protected blink1_device *m_device;
	// The index of our device within the blink1 library's cache.
	protected int m_cachedIndex;
	// The device type of our device;
	protected immutable Blink1Type m_type;
	protected immutable ubyte m_maxPatterns;
	protected Duration m_defaultDur = dur!"msecs"(500);
	protected bool m_blocking = false;

	private Duration m_serverDownTimeout;
	private bool m_serverDownStayLit;
	private ubyte m_serverDownStartPosition;
	private ubyte m_serverDownEndPosition;

	private this(blink1_device *device) {
		this.m_device = device;
		m_cachedIndex = blink1_getCacheIndexByDev(device);
		m_type = blink1_deviceTypeById(m_cachedIndex);

		if(m_type == Blink1Type.BLINK1_MK1) {
			m_maxPatterns = 12;
		} else if (m_type == Blink1Type.BLINK1_MK2 || m_type == Blink1Type.BLINK1_MK3) {
			m_maxPatterns = 32;
		} else {
			m_maxPatterns = 0;
		}
	}

	/**
	 * Opens the first found default Blink1Device. No guarantees are given which one is found first.
	 * Throws a Blink1NotFoundException if no device could be found.
	 */
	public static Blink1Device open() {
		blink1_device *dev = blink1_open();
		enforce!Blink1NotFoundException(dev != null, "Could not find default Blink1Device");
		return new Blink1Device(dev);
	}

	/**
	 * Opens the device by the OS-specific path.
	 * Throws a Blink1NotFoundException if no device could be found with the given path.
	 */
	public static Blink1Device openByPath(string path) {
		blink1_device *dev = blink1_openByPath(path.toStringz());
		enforce!Blink1NotFoundException(dev != null, "Could not find Blink1Device with path %s".format(path));
		return new Blink1Device(dev);
	}

	/**
	 * Opens the device by the given serial number.
	 * Throws a Blink1NotFoundException if no device could be found with the given serial number.
	 */
	public static Blink1Device openBySerial(string serial) {
		blink1_device *dev = blink1_openBySerial(serial.toStringz());
		enforce!Blink1NotFoundException(dev != null, "Could not find Blink1Device with serial %s".format(serial));
		return new Blink1Device(dev);
	}

	/**
	 * Opens the device by the given index.
	 * The index should range from 0 to blink1_max_devices.
	 * Throws a Blink1NotFoundException if no device could be found with the given index;
	 */
	public static Blink1Device openByIndex(uint index) {
		blink1_device *dev = blink1_openById(index);
		enforce!Blink1NotFoundException(dev != null, "Could not find Blink1Device with serial %u".format(index));
		return new Blink1Device(dev);
	}

	/**
	 * Closes this device.
	 */
	public void close() {
		blink1_close_internal(m_device);
	}

	/**
	 * Returns the firmware version integer.
	 * The hundreds represent the major version, while the units and tenths represent the minor version,
	 * e.g. "v3.3" = 303;
	 */
	public int getFwVersionInt() {
		return blink1_getVersion(m_device);
	}

	public string getFwVersion() {
		int fwVersion = getFwVersionInt();
		int major = fwVersion / 100;
		int minor = fwVersion % 100;
		return "v%d.%d".format(major, minor);
	}

	/**
	 * Fades the color to the specified value with the given duration.
	 * Params:
	 *     r = red component of color (0 <= r <= 255)
	 *     g = green component of color (0 <= g <= 255)
	 *     b = blue component of color (0 <= b <= 255)
	 *     dur = duration of the fade animation. Maximum duration is 65,355 milliseconds. Defaults to `defaultDuration`
	 *     led = which LED to fade. Defaults to all LEDs
	 *   
	 */
	public void fadeToRGB(ubyte r, ubyte g, ubyte b, Duration dur = dur!"seconds"(-1), LED led = LED.ALL) {
		if (dur.isNegative) dur = this.m_defaultDur;
		blink1_fadeToRGBN(m_device, cast(short) dur.total!"msecs", r, g, b, cast(ubyte) led);
		if (m_blocking) Thread.sleep(dur);
	}

	/**
	 * Immediatelty changes the color to the given value
	 * Params:
	 *     r = red component of color (0 <= r <= 255)
	 *     g = green component of color (0 <= g <= 255)
	 *     b = blue component of color (0 <= b <= 255)
	 */
	public void setRGB(ubyte r, ubyte g, ubyte b) {
		blink1_setRGB(m_device, r, g, b);
	}

	/**
	 * Enables the blink1's dead man's trigger. This will play the pattern on the LED when `pokeServerDown` hasn't
	 * been called after `timeout` has been passed.
	 * Params:
	 *     timeout = when to start blinking.
	 *     stayLit = if the LED should stay on after playing the pattern.
	 *     startPosition = The starting position within the pattern. Default: 0
	 *     endPostion = The ending position of the pattern.
	 */
	public void enableServerDown(Duration timeout, bool stayLit, ubyte startPosition = 0, ubyte endPosition = 255) {
		if (endPosition == 255) endPosition = m_maxPatterns;
		this.m_serverDownTimeout = timeout;
		this.m_serverDownStayLit = stayLit;
		this.m_serverDownStartPosition = startPosition;
		this.m_serverDownEndPosition = endPosition;
		blink1_serverdown(m_device,  1, cast(short) timeout.total!"msecs", cast(ubyte) stayLit, 
				startPosition, endPosition);
	}

	/**
	 * Notifies the LED the "server" is still running, so it won't turn on. See `enableServerDown`.
	 */
	public void pokeServerDown() {
		blink1_serverdown(m_device, cast(ubyte) 1, cast(ushort) this.m_serverDownTimeout.total!"msecs", 
				cast(ubyte) this.m_serverDownStayLit, this.m_serverDownStartPosition, 
				this.m_serverDownEndPosition);
	}

	/**
	 * Disables the serverDown mode. See `enableServerDown`.
	 */
	public void disableServerDown() {
		blink1_serverdown(m_device, 0, 0, 0, 0, 0);
	}

	public ubyte[] readNote(ubyte id) {
		enforce!UnsupportedOperationException(m_type == Blink1Type.BLINK1_MK3);
		enforce!Exception(id < MAX_NOTES, "Device supports up to %d notes, tried to read %d".format(MAX_NOTES, id));
		ubyte[] noteBuffer = new ubyte[MAX_NOTE_SIZE];
		ubyte * noteBufferPtr = noteBuffer.ptr;
		blink1_readNote(m_device, id, &noteBufferPtr);

		return noteBuffer;
	}

	/**
	 *
	 */
	public void writeNote(ubyte id, immutable ubyte[] note) {
		// blink1_writeNote will happilly write garbage, try to sanitize it
		// by setting remaining data to zero
		enforce!UnsupportedOperationException(m_type == Blink1Type.BLINK1_MK3);
		enforce!Exception(id < MAX_NOTES, "Device supports up to %d notes, tried to write %d".format(MAX_NOTES, id));
		ulong length = min(MAX_NOTE_SIZE, note.length);
		ubyte[MAX_NOTE_SIZE] realNote;
		realNote[0..length] = note[0..length];
		blink1_writeNote(m_device, id, realNote.ptr);
	}

	/**
	 * Sets the default duration for fade animations if no duration parameter is given.
	 */
	@property void defaultDuration(Duration dur) {
		this.m_defaultDur = dur;
	}

	/**
	 * Gets the default duration for fade animations if no duration parameter is given.
	 */
	@property Duration defaultDuration() {
		return this.m_defaultDur;
	}

	/**
	 * Enables/disables blocking mode
	 *
	 * If blocking mode is enabled, calls to `fadeToRGB` will sleep the thread until the
	 * animation is finished. If blocking mode is disabled, `fadeToRGB` will immediatly return.
	 */
	@property void blocking(bool blocking) {
		this.m_blocking = blocking;
	}

	/**
	 * Returns if blocking mode is enabled. See `blocking(bool)` above as well.
	 */
	@property bool blocking() {
		return this.m_blocking;
	}

	/**
	 * Gets the device type of this device.
	 */
	@property Blink1Type type() immutable {
		return this.m_type;
	}
};
