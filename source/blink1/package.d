/**
 * This is the module which contains the Object-Oriented D wrapper.
 */
module blink1;

import core.thread;

import std.algorithm;
import std.datetime;
import std.exception;
import std.string;

import blink1.clib;

/**
 * General exception with a BLink1 device.
 *
 * Usually thrown when an IO error occurs with the USB device,
 * which is usually caused by an user unplugging the blink(1) device.
 */
class Blink1Exception : Exception {
	mixin basicExceptionCtors;
}
/**
 * Thrown when no Blink1 could be found.
 */
class Blink1NotFoundException : Blink1Exception {
	mixin basicExceptionCtors;
}

/**
 * Thrown when a device does not support the requested method. 
 *
 * This exception is for example thrown when the [Blink1Device.readNote] and [Blink1Device.writeNote] 
 * functions are called on MK1 and MK2 devices, which do not support the note feature.
 */
class UnsupportedOperationException : Blink1Exception {
	mixin basicExceptionCtors;
}

/**
 * Enum containing the different models of the blink(1) devices out there.
 *
 * Simple alias for the type found within the C library.
 *
 * See_Also: blink1.clib.blink1Type_t
 */
alias Blink1Type = blink1Type_t;

alias RGB = rgb_t;

/**
 * Represents the LED on the device.
 */
enum LED {
	/// Special value: All LEDS
	ALL = 0,
	/// First LED
	ONE = 1,
	/// Second LED.
	TWO = 2
}

/// Describes the boot mode of the MK2 and later devices.
enum BootMode {
	/// Play the stored pattern if only power is connected, otherwise play nothing.
	NORMAL = 0,
	/// Play the stored pattern
	PLAY = 1,
	/// Do not play anything
	OFF = 2
}

/**
 * Argument for controlling play behaviour.
 */
enum PlayMode {
	STOP = 0, /// Stop playing the pattern
	PLAY = 1  /// Start playing the pattern.
}

/// Represents the boot parameters
struct StartupParameters {
	BootMode bootMode;
	/// From which index the device should start playing.
	ubyte playStart;
	/// Until which index the device should play.
	ubyte playEnd;
	/// The amount of times it should play. 0 = infinite.
	ubyte playCount;
};

/**
 * Represents a pattern line.
 */
struct PatternLine {
	/// The color of this pattern.
    RGB color;
	/// Time in to transition towards this pattern.
    Duration duration;
    /// The led.
    LED led;
}

/// Playing state of the blink(1) LED
struct PlayState {
	/// Wether the blink(1) is playing or not.
	PlayMode playMode;
	/// Starting position of the pattern.
	ubyte playStart;
	/// The pattern position to stop playing at
	ubyte playEnd;
	/// Amount of times the pattern should be played. 0 = infinite
	ubyte playCount;
	/// Current playing position
	ubyte playPosition;
}

/**
 * Represents a physical device.
 *
 * To get a reference to a device, one should call either [open], [openByPath], [openBySerial] or
 * [openByIndex]. After being done with the device, please call [close] to release OS resources.
 */
class Blink1Device {


	/**
	 * The maximum amount of notes that this device may hold.
	 */
	// These are not static since they may change with new hardware revisions or firmware versions.
	public immutable maxNotes = 10;
	public immutable maxNoteSize = blink1_note_size;

	/// Our "handle" to the blink led.
	protected blink1_device *m_device;
	/// The index of our device within the blink1 library's cache.
	protected int m_cachedIndex;
	/// The device type of our device;
	private immutable Blink1Type m_type;
	// Keep the firmware version around
	private int m_fwVersion;
	private immutable ubyte m_maxPatterns;
	private Duration m_defaultDur = dur!"msecs"(500);
	private bool m_blocking = false;

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
		m_fwVersion = blink1_getVersion(m_device);
	}

	/**
	 * Opens the first found default Blink1Device. No guarantees are given which one is found first.
	 *
	 * Throws: a Blink1NotFoundException if no device could be found.
	 */
	@trusted
	public static Blink1Device open() {
		blink1_device *dev = blink1_open();
		enforce!Blink1NotFoundException(dev != null, "Could not find default Blink1Device");
		return new Blink1Device(dev);
	}

	/**
	 * Obtains a Blink1 device by the OS-specific path.
	 *
	 * Params:
	 *     path = The OS-specific path to the USB device.
	 *
	 * Throws: a Blink1NotFoundException if no device could be found with the given path.
	 */
	@trusted
	public static Blink1Device openByPath(string path) {
		blink1_device *dev = blink1_openByPath(path.toStringz());
		enforce!Blink1NotFoundException(dev != null, "Could not find Blink1Device with path %s".format(path));
		return new Blink1Device(dev);
	}

	/**
	 * Opens the device by the given serial number.
	 *
	 * Params:
	 *     serial = The serial number of the device.
	 * Throws: a Blink1NotFoundException if no device could be found with the given serial number.
	 */
	@trusted
	public static Blink1Device openBySerial(string serial) {
		blink1_device *dev = blink1_openBySerial(serial.toStringz());
		enforce!Blink1NotFoundException(dev != null, "Could not find Blink1Device with serial %s".format(serial));
		return new Blink1Device(dev);
	}

	/**
	 * Opens the device by the given index.
	 * 
	 * Params:
	 *     index = The index of the device. It should range from 0 to blink1_max_devices.
	 *
	 * Throws: a Blink1NotFoundException if no device could be found with the given index;
	 *
	 * See_Also: connectedDeviceCount
	 */
	@trusted
	public static Blink1Device openByIndex(uint index) {
		blink1_device *dev = blink1_openById(index);
		enforce!Blink1NotFoundException(dev != null, "Could not find Blink1Device with serial %u".format(index));
		return new Blink1Device(dev);
	}

	/**
	 * Returns the amount of detected Blink1 devices.
	 */
	@trusted
	public static int connectedDeviceCount() {
		return blink1_enumerate();
	}

	/**
	 * Closes this device.
	 */
	@trusted
	public void close() {
		blink1_close_internal(m_device);
	}

	/**
	 * Returns the firmware version integer.
	 *
	 * The hundreds represent the major version, while the units and tenths represent the minor version,
	 * e.g. "v3.3" = 303;
	 */
	@safe
	public int getFwVersionInt() {
		return m_fwVersion;
	}

	/**
	 * Returns the firmware version as a string in the form of v{major}.{minor}
	 */
	@safe
	public string getFwVersion() {
		int fwVersion = getFwVersionInt();
		int major = fwVersion / 100;
		int minor = fwVersion % 100;
		return "v%d.%d".format(major, minor);
	}

	/**
	 * Fades the color to the specified value with the given duration.
	 *
	 * Params:
	 *     r = red component of color (0 <= r <= 255)
	 *     g = green component of color (0 <= g <= 255)
	 *     b = blue component of color (0 <= b <= 255)
	 *     dur = duration of the fade animation. Maximum duration is 65,355 milliseconds. Defaults to `defaultDuration`
	 *     led = which LED to fade. Defaults to all LEDs
	 *   
	 * See_Also: [defaultDuration], [setRGB], [fadeToHSV]
	 * Throws: Blink1Exception on error.
	 */
	@trusted
	public void fadeToRGB(ubyte r, ubyte g, ubyte b, Duration dur = seconds(-1), LED led = LED.ALL) {
		if (dur.isNegative) dur = this.m_defaultDur;
		throwIfFail(blink1_fadeToRGBN(m_device, cast(short) dur.total!"msecs", r, g, b, cast(ubyte) led));
		if (m_blocking) Thread.sleep(dur);
	}

	/**
	 * Fades the color to the specified value with the given duration.
	 *
	 * Params:
	 *     h = hue component of color (0 <= h <= 255)
	 *     s = saturation component of color (0 <= s <= 255)
	 *     v = value component of color (0 <= v <= 255)
	 *     dur = duration of the fade animation. Maximum duration is 65,355 milliseconds. Defaults to `defaultDuration`
	 *     led = which LED to fade. Defaults to all LEDs
	 *   
	 * See_Also: [defaultDuration], [setHSV], [fadeToRGB]
	 * Throws: Blink1Exception on error.
	 */
	@safe
	public void fadeToHSV(ubyte h, ubyte s, ubyte v, Duration dur = seconds(-1), LED led = LED.ALL) {
		RGB color = fromHSV(h, s, v);
		fadeToRGB(color.r, color.g, color.b, dur, led);
	}

	/**
	 * Immediatelty changes the color to the given value
	 *
	 * Params:
	 *     r = red component of color (0 <= r <= 255)
	 *     g = green component of color (0 <= g <= 255)
	 *     b = blue component of color (0 <= b <= 255)
	 *
	 * See_Also: [fadeToRGB], [setHSV]
	 * Throws: Blink1Exception on error.
	 */
	@trusted
	public void setRGB(ubyte r, ubyte g, ubyte b) {
		throwIfFail(blink1_setRGB(m_device, r, g, b));
	}

	/**
	 * Immediatelty changes the color to the given value
	 *
	 * Params:
	 *     h = hue component of color (0 <= h <= 255)
	 *     s = saturation component of color (0 <= s <= 255)
	 *     v = value component of color (0 <= v <= 255)
	 *
	 * See_Also: [fadeToRGB], [setRGB]
	 * Throws: Blink1Exception on error.
	 */
	@safe
	public void setHSV(ubyte h, ubyte s, ubyte v) {
		RGB color = fromHSV(h, s, v);
		setRGB(color.r, color.g, color.b);
	}

	/**
	 * Enables the blink1's dead man's trigger. This will play the pattern on the LED when `pokeServerDown` hasn't
	 * been called after `timeout` has been passed.
	 *
	 * Params:
	 *     timeout = when to start blinking.
	 *     stayLit = if the LED should stay on after playing the pattern.
	 *     startPosition = The starting position within the pattern. Default: 0
	 *     endPostion = The ending position of the pattern.
	 */
	@trusted
	public void enableServerDown(Duration timeout, bool stayLit, ubyte startPosition = 0, ubyte endPosition = 255) {
		if (endPosition == 255) endPosition = m_maxPatterns;
		this.m_serverDownTimeout = timeout;
		this.m_serverDownStayLit = stayLit;
		this.m_serverDownStartPosition = startPosition;
		this.m_serverDownEndPosition = endPosition;
		throwIfFail(blink1_serverdown(m_device,  1, cast(short) timeout.total!"msecs", cast(ubyte) stayLit, 
				startPosition, endPosition));
	}

	/**
	 * Notifies the LED the "server" is still running, so it won't turn on. 
	 * 
	 * See_Also: enableServerDown
	 */
	@trusted
	public void pokeServerDown() {
		throwIfFail(blink1_serverdown(m_device, cast(ubyte) 1, cast(ushort) this.m_serverDownTimeout.total!"msecs", 
				cast(ubyte) this.m_serverDownStayLit, this.m_serverDownStartPosition, 
				this.m_serverDownEndPosition));
	}

	/**
	 * Disables the serverDown mode. 
	 *
	 * See_Also: enableServerDown
	 */
	@trusted
	public void disableServerDown() {
		throwIfFail(blink1_serverdown(m_device, 0, 0, 0, 0, 0));
	}

	/**
	 * Plays a stored pattern. The end and count parameters are only supported on MK2 and later
	 * devices.
	 *
	 * Params:
	 *     start = The pattern position to start playing from.
	 *     end =  The final pattern position to stop playing.
	 *     count = The amount of times to loop this pattern. 0 = infinite.
	 * See_Also: [stop]
	 * Throws: Blink1Exception if error
	 */
	@trusted
	public void play(ubyte start = 0, ubyte end = 255, ubyte count = 0) {
		throwIfFail(blink1_playloop(m_device, cast(ubyte) PlayMode.PLAY, start, end, count));
	}


	/// Ditto
	@trusted
	public void play(ubyte start = 0) {
		throwIfFail(blink1_play(m_device, cast(ubyte) PlayMode.PLAY, start));
	}

	/**
	 * Stop playing whatever pattern the device is playing.
	 * See_Also: [play]
	 */
	@trusted
	public void stop() {
		throwIfFail(blink1_play(m_device, cast(ubyte) PlayMode.STOP, 255));
	}

	/**
	 * Read the play state. Supported on MK2 devices and later.
	 *
	 * Throws: Blink1Exception if error
	 */
	@trusted
	public PlayState readPlayState() {
		PlayState state;
		throwIfFail(blink1_readPlayState(m_device, cast(ubyte*) &state.playMode, &state.playStart,
					&state.playEnd, &state.playCount, &state.playPosition));
		return state;
	}

	/**
	 * Reads the stored pattern line at position `pos`.
	 *
	 * Params:
	 *     pos = The position of the pattern stored on the device, starting from 0
	 * Returns: The stored PatternLine
	 * Throws: Blink1Exception if an error occurs.
	 */
	@trusted
	public PatternLine readPatternLine(ubyte pos) {
		PatternLine result;
		ushort fadeMillis;
		if (getFwVersionInt >= 204) {
			throwIfFail(blink1_readPatternLineN(m_device, &fadeMillis, &result.color.r, 
						&result.color.g, &result.color.b, cast(ubyte*) &result.led, pos));
			
		} else {
			throwIfFail(blink1_readPatternLine(m_device, &fadeMillis, &result.color.r, 
						&result.color.g, &result.color.b, pos));
		}
		result.duration = msecs(fadeMillis);
		return result;
	}

	/**
	 * Writes a pattern line to the device.
	 *
	 * On MK1 devices this will store it in nonvolatile storage.
	 * On MK2 and later devices this will store it in RAM. Call [savePattern] to store it in 
	 * nonvolatile storage.
	 * 
	 * Params:
	 *     pos = The position to write to, starting from zero.
	 *     patternLine = The patternLine to store.
	 * Throws: Blink1Exception if an error occurs.
	 */
	@trusted
	public void writePatternLine(ubyte pos, PatternLine patternLine) {
		writePatternLineRGB(pos, patternLine.color.r, patternLine.color.g, patternLine.color.b, 
				patternLine.duration, patternLine.led);
	}

	/**
	 * Writes a pattern line to the device.
	 *
	 * On MK1 devices this will store it in nonvolatile storage.
	 * On MK2 and later devices this will store it in RAM. Call [savePattern] to store it in 
	 * nonvolatile storage.
	 * 
	 * Params:
	 *     pos = The position to write to, starting from zero.
	 *     r = red component
	 *     g = green component
	 *     b = blue component
	 *     duration = time it takes to fade
	 *     led = The LED to use.
	 * Throws: Blink1Exception if an error occurs.
	 */
	@trusted
	public void writePatternLineRGB(ubyte pos, ubyte r, ubyte g, ubyte b, Duration duration = seconds(01), 
			LED led = LED.ALL) {
		if (duration.isNegative) duration = m_defaultDur;

		if (getFwVersionInt >= 204) {
			throwIfFail(blink1_setLEDN(m_device, cast(ubyte) led));
		}
		throwIfFail(blink1_writePatternLine(m_device, cast(ushort) duration.total!"msecs",
				r, g, b, pos));
	}

	/**
	 * Writes a pattern line to the device.
	 *
	 * On MK1 devices this will store it in nonvolatile storage.
	 * On MK2 and later devices this will store it in RAM. Call [savePattern] to store it in 
	 * nonvolatile storage.
	 * 
	 * Params:
	 *     pos = The position to write to, starting from zero.
	 *     h = hue component
	 *     s = saturation component
	 *     v = value component
	 *     duration = time it takes to fade
	 *     led = The LED to use.
	 * Throws: Blink1Exception if an error occurs.
	 */
	@trusted
	public void writePatternLineHSV(ubyte pos, ubyte h, ubyte s, ubyte v, Duration duration = seconds(01), 
			LED led = LED.ALL) {
		RGB color = fromHSV(h, s, v);
		writePatternLineRGB(pos, color.r, color.g, color.b, duration, led);
	}

	/**
	 * Saves the pattern in the device's ram to nonvolatile memory.
	 * Only works on MK2 devices with firmware 204 or later, or later devices.
	 *
	 * Throws: Blink1Exception if error
	 */
	@trusted
	public void savePattern() {
		throwIfFail(blink1_savePattern(m_device));
	}

	/**
	 * Reads the startup parameters of the device.
	 *
	 * Throws: Blink1Exception if error
	 */
	@trusted
	public StartupParameters getStartupParameters() {
		StartupParameters params;
		throwIfFail(blink1_getStartupParams(m_device, cast(ubyte*) &params.bootMode,
				&params.playStart, &params.playEnd, &params.playCount));
		return params;
	}



	/**
	 * Sets the startup parameters
	 * 
	 * Params:
	 *     bootMode = the boot mode
	 *     playStart = From which stored pattern line to start playing from
	 *     playEnd =  To which stored pattern line to play to
	 *     playCount = How many times to repeat the pattern. 0 = infinite.
	 *
	 * Throws: Blink1Exception if error
	 */
	@trusted
	public void setStartupParameters(BootMode bootMode, ubyte playStart, ubyte playEnd, ubyte playCount) {
		throwIfFail(blink1_setStartupParams(m_device, cast(ubyte) bootMode, playStart, playEnd, playCount));
	}

	/// Ditto
	@safe
	public void setStartupParameters(StartupParameters params) {
		setStartupParameters(params.bootMode, params.playStart, params.playEnd, params.playCount);
	}

	/**
	 * Reads a note from the device.
	 *
	 * Params:
	 *     id = The id of the note, 0 <= id < maxNotes
	 * Returns: The read note
	 * Throws: UnsupportedOperationException if id < [maxNotes]
	 */
	@trusted
	public ubyte[] readNote(ubyte id) {
		enforce!UnsupportedOperationException(m_type == Blink1Type.BLINK1_MK3);
		enforce!Exception(id < maxNotes, "Device supports up to %d notes, tried to read %d".format(maxNotes, id));
		ubyte[] noteBuffer = new ubyte[maxNoteSize];
		ubyte * noteBufferPtr = noteBuffer.ptr;
		blink1_readNote(m_device, id, &noteBufferPtr);

		return noteBuffer;
	}

	/**
	 * Writes a note with the given id.
	 *
	 * Params:
	 *     id = The id of the note to write to, 
	 *     note = The note to write. Maximum length is maxNoteSize. Longer notes will be silently
	 *            truncated.
	 */
	@trusted
	public void writeNote(ubyte id, immutable ubyte[] note) {
		// blink1_writeNote will happilly write garbage, try to sanitize it
		// by setting remaining data to zero
		enforce!UnsupportedOperationException(m_type == Blink1Type.BLINK1_MK3);
		enforce!Exception(id < maxNotes, "Device supports up to %d notes, tried to write %d".format(maxNotes, id));
		ulong length = min(maxNoteSize, note.length);
		ubyte[] realNote = new ubyte[](maxNoteSize);
		realNote[0..length] = note[0..length];
		blink1_writeNote(m_device, id, realNote.ptr);
	}

	/**
	 * Sets the default duration for fade animations if no duration parameter is given.
	 */
	@safe
	@property void defaultDuration(Duration dur) {
		this.m_defaultDur = dur;
	}

	/**
	 * Gets the default duration for fade animations if no duration parameter is given.
	 */
	@safe
	@property Duration defaultDuration() {
		return this.m_defaultDur;
	}

	/**
	 * Enables/disables blocking mode
	 *
	 * If blocking mode is enabled, calls to `fadeToRGB` will sleep the thread until the
	 * animation is finished. If blocking mode is disabled, `fadeToRGB` will immediatly return.
	 */
	@safe
	@property void blocking(bool blocking) {
		this.m_blocking = blocking;
	}

	/**
	 * Returns if blocking mode is enabled. 
	 *
	 * See_Also: blocking(bool)
	 */
	@safe
	@property bool blocking() {
		return this.m_blocking;
	}

	/**
	 * Gets the device type of this device.
	 */
	@safe
	@property Blink1Type type() {
		return this.m_type;
	}

	/**
	 * The serial number of this device.
	 */
	@trusted
	@property string serial() {
		import std.conv;
		char* str = blink1_getCachedSerial(this.m_cachedIndex);
		return fromStringz(str).to!string;
	}

	/**
	 * The path of this device
	 */
	@trusted
	@property string path() {
		import std.conv;
		char* str = blink1_getCachedPath(this.m_cachedIndex);
		return fromStringz(str).to!string;
	}

	/**
	 * Returns the maximum amount of patterns this device may hold.
	 */
	@safe
	@property int maxPatterns() {
		return m_maxPatterns;
	}

	/*
	 * Private methods
	 */

	/**
	 * Throws an exception if `result < 0`.
	 * Params:
	 *     result = The result code of the operation.
	 * Throws: E
	 */
	@trusted
	private void throwIfFail(E = Blink1Exception)(int result) {
		import std.conv;
		enforce!E(result >= 0, fromStringz(blink1_error_msg(result)).to!string());
	}

	/**
	 * Converts HSV to RGB
	 */
	@trusted
	private static RGB fromHSV(ubyte h, ubyte s, ubyte v) {
		RGB color;
		ubyte[] tmp = [h, s, v];
		hsbtorgb(&color, tmp.ptr);
		return color;
	}
};
