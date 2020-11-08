/**
 * Barebones C wrapper for the blink(1) C library.
 *
 * blink(1) C library -- aka "blink1-lib"
 *
 * Part of the blink(1) open source hardware project
 * See https://github.com/todbot/blink1 for details
 *
 * 2012-2014, Tod E. Kurt, http://todbot.com/blog/ , http://thingm.com/
 *
 */

module blink1.clib;

// Provides FILE pointer
import core.stdc.stdio : FILE;


extern (C) {

immutable int blink1_max_devices = 32;

immutable int cache_max = blink1_max_devices;
//#define cache_max 16
immutable int serialstrmax = 8 + 1;
immutable int pathstrmax = 1024;

immutable int blink1mk2_serialstart = 0x20000000;
immutable int blink1mk3_serialstart = 0x30000000;

immutable int BLINK1_VENDOR_ID = 0x27B8; /* = 0x27B8 = 10168 = thingm */
immutable int BLINK1_DEVICE_ID = 0x01ED; /* = 0x01ED */

immutable int blink1_report_id = 1;
immutable int blink1_report_size = 8;
immutable int blink1_report2_id = 2;
immutable int blink1_report2_size = 60;
immutable int blink1_buf_size = blink1_report_size + 1;
immutable int blink1_buf2_size = blink1_report2_size + 1;

immutable int blink1_note_size = 50;

enum blink1Type_t {
	/// Unknown type
    BLINK1_UNKNOWN = 0,
    /// The original one from the kickstarter
    BLINK1_MK1,   
    /// The updated one with 2 LEDs
    BLINK1_MK2,   
    /// 2018 one based on EFM32HG
    BLINK1_MK3
}

// struct blink1_device_;
struct hid_device_;
alias hid_device = hid_device_;

version(USE_HIDAPI) {
	alias blink1_device = hid_device_; /**< opaque blink1 structure */
} else {
	version(USE_HIDDATA) {
		alias blink1_device = usbDevice; /**< opaque blink1 structure */
	} else {
		pragma(msg, "version identifier USE_HIDAPI or USE_HIDDATA wasn't defined, defaulting to USE_HIDAPI");
		alias blink1_device = hid_device_; /**< opaque blink1 structure */
	}
}


//
// -------- BEGIN PUBLIC API ----------
//

// you can define "extern int blink1_lib_verbose"
// and set it to "1" to enable low-level debugging

struct rgb_t {
    ubyte r; ubyte g; ubyte b;
}

struct patternline_t {
    rgb_t color;
    ushort millis;
    /// number of led, or 0 for all
    ubyte ledn;
}


/**
 * Scan USB for blink(1) devices.
 * Returns: number of devices found
 */
int          blink1_enumerate();

/**
 * Scan USB for devices by given VID,PID.
 *
 * Params:
 *     vid = vendor ID
 *     pid = product ID
 *
 * Returns: number of devices found
 */
int          blink1_enumerateByVidPid(int vid, int pid);

/**
 * Open first found blink(1) device.
 *
 * Returns: pointer to opened [blink1_device] or NULL if no blink1 found
 */
blink1_device* blink1_open();

/**
 * Open blink(1) by USB path.
 *
 * Note: this is platform-specific, and port-specific.
 *
 * Params:
 *     path = string of platform-specific path to blink1
 *
 * Returns: [blink1_device] or NULL if no blink1 found
 */
blink1_device* blink1_openByPath(const char* path);

/**
 * Open blink(1) by 8-digit serial number.
 *
 * Params:
 *     serial = 8-hex digit serial number
 *
 * Returns: [blink1_device] or NULL if no blink1 found
 */
blink1_device* blink1_openBySerial(const char* serial);

/**
 * Open by "id", which if from 0-[blink1_max_devices] is index
 *  or if [blink1_max_devices], is numerical representation of serial number
 *
 * Params: 
 *    id = ordinal 0-15 id of blink1 or numerical rep of 8-hex digit serial
 * Returns: blink1_device or NULL if no blink1 found
 */
blink1_device* blink1_openById(uint id );


/**
 * Close opened blink1 device.
 *
 * Safe to call blink1_close on already closed device.
 *
 * Params:
 *     dev = blink1_device
 */
void blink1_close_internal( blink1_device* dev );

/**
 * Low-level write to blink1 device.
 *
 * Used internally by blink1-lib
 */
int blink1_write( blink1_device* dev, void* buf, int len);
/**
 * Low-level read from blink1 device.
 *
 * Used internally by blink1-lib
 */
int blink1_read( blink1_device* dev, void* buf, int len);

int blink1_read_nosend( blink1_device* dev, void* buf, int len);

/**
 * Get blink1 firmware version.
 *
 * Params:
 *     dev = opened blink1 device
 * Returns: version as scaled int number (e.g. "v1.1" = 101)
 */
int blink1_getVersion(blink1_device *dev);

/**
 * Fade blink1 to given RGB color over specified time.
 *
 * Params:
 *     dev = blink1 device to command
 *     fadeMillis = time to fade in milliseconds
 *     r = red part of RGB color
 *     g = green part of RGB color
 *     b = blue part of RGB color
 *
 * Returns: -1 on error, 0 on success
 */
int blink1_fadeToRGB(blink1_device *dev, ushort fadeMillis,
                     ubyte r, ubyte g, ubyte b );

/**
 * Fade specific LED on blink1mk2 to given RGB color over specified time.
 * @note For mk2 devices.
 * @param dev blink1 device to command
 * @param fadeMillis time to fade in milliseconds
 * @param r red part of RGB color
 * @param g green part of RGB color
 * @param b blue part of RGB color
 * @param n which LED to address (0=all, 1=1st LED, 2=2nd LED)
 * @return -1 on error, 0 on success
 */
int blink1_fadeToRGBN(blink1_device *dev, ushort fadeMillis,
                      ubyte r, ubyte g, ubyte b, ubyte n );
/**
 * Set blink1 immediately to a specific RGB color.
 * @note If mk2, sets all LEDs immediately
 * @param dev blink1 device to command
 * @param r red part of RGB color
 * @param g green part of RGB color
 * @param b blue part of RGB color
 * @return -1 on error, 0 on success
 */
int blink1_setRGB(blink1_device *dev, ubyte r, ubyte g, ubyte b );

/**
 * Read current RGB value on specified LED.
 * @note For mk2 devices only.
 * @param dev blink1 device to command
 * @param r pointer to red part of RGB color
 * @param g pointer to green part of RGB color
 * @param b pointer to blue part of RGB color
 * @param n which LED to get (0=1st, 1=1st LED, 2=2nd LED)
 * @return -1 on error, 0 on success
 */
int blink1_readRGB(blink1_device *dev, ushort* fadeMillis,
                   ubyte* r, ubyte* g, ubyte* b,
                   ubyte ledn);
/**
 * Attempt to read current RGB value for mk1 devices.
 * @note Called by blink1_setRGB() if device is mk1.
 * @note Does not always work.
 * @param dev blink1 device to command
 * @param r pointer to red part of RGB color
 * @param g pointer to green part of RGB color
 * @param b pointer to blue part of RGB color
 * @return -1 on error, 0 on success
 */
int blink1_readRGB_mk1(blink1_device *dev, ushort* fadeMillis,
                       ubyte* r, ubyte* g, ubyte* b);

/**
 * Read eeprom on mk1 devices
 * @note For mk1 devices only
 */
int blink1_eeread(blink1_device *dev, ushort addr, ubyte* val);
/**
 * Write eeprom on mk1 devices
 * @note For mk1 devices only
 */
int blink1_eewrite(blink1_device *dev, ushort addr, ubyte val);

/**
 * Read serial number from mk1 device. Does not work.
 * @note Use USB descriptor serial number instead.
 * @note for mk1 devices only.
 * @note does not work.
 */
int blink1_serialnumread(blink1_device *dev, ubyte** serialnumstr);
/**
 * Write serial number to mk1 device. Does not work.
 * @note for mk1 devices only.
 * @note does not work.
 */
int blink1_serialnumwrite(blink1_device *dev, ubyte* serialnumstr);

/**
 * Tickle blink1 serverdown functionality.
 * @note 'st' param for mk2 firmware only
 * @param on  enable or disable: enable=1, disable=0
 * @param millis milliseconds to wait until triggering (up to 65,355 millis)
 * @param stay lit (st=1) or set off() (st=0)
 * @param startpos pattern start position (fw 205+)
 * @param endpos pattern end pos (fw 205+)
 */
int blink1_serverdown(blink1_device *dev, ubyte on, ushort millis,
                      ubyte st, ubyte startpos, ubyte endpos);

/**
 * Play color pattern stored in blink1.
 * @param dev blink1 device to command
 * @param play boolean: 1=play, 0=stop
 * @param pos position to start playing from
 * @return -1 on error, 0 on success
 */
int blink1_play(blink1_device *dev, ubyte play, ubyte pos);

/**
 * Play color pattern stored in blink1mk2.
 * @note For mk2 devices only.
 * @param dev blink1 device to command
 * @param play boolean: 1=play, 0=stop
 * @param startpos position to start playing from
 * @param endpos position to end playing
 * @param count number of times to play (0=forever)
 * @return -1 on error, 0 on success
 */
int blink1_playloop(blink1_device *dev, ubyte play, ubyte startpos, ubyte endpos, ubyte count);

/**
 * Read the current state of a playing pattern.
 * @note For mk2 devices only.
 * @param dev blink1 device to command
 * @param playing pointer to play/stop boolean
 * @param playstart pointer to start position
 * @param playend pointer to end position
 * @param playcount pointer to count left
 * @param playpos pointer to play position
 * @return -1 on error, 0 on success
 */
int blink1_readPlayState(blink1_device *dev, ubyte * playing,
                         ubyte* playstart, ubyte* playend,
                         ubyte* playcount, ubyte* playpos);

/**
 * Write a color pattern line to blink1.
 * @note on mk1 devices, this saves the pattern line to nonvolatile storage.
 * @note on mk2 devices, this only saves to RAM (see savePattern() for nonvol)
 * @param dev blink1 device to command
 * @param r red part of RGB color
 * @param g green part of RGB color
 * @param b blue part of RGB color
 * @param pos pattern line number 0-max_patt (FIXME: put note about this)
 * @return -1 on error, 0 on success
 */
int blink1_writePatternLine(blink1_device *dev, ushort fadeMillis,
                            ubyte r, ubyte g, ubyte b,
                            ubyte pos);
/**
 * Read a color pattern line to blink1.
 * @param dev blink1 device to command
 * @param fadeMillis pointer to milliseconds to fade to RGB color
 * @param r pointer to store red color component
 * @param g pointer to store green color component
 * @param b pointer to store blue color component
 * @return -1 on error, 0 on success
 */
int blink1_readPatternLine(blink1_device *dev, ushort* fadeMillis,
                           ubyte* r, ubyte* g, ubyte* b,
                           ubyte pos);
/**
 * Read a color pattern line to blink1.
 * @note ledn param only works on fw204+ devices
 * @param dev blink1 device to command
 * @param fadeMillis pointer to milliseconds to fade to RGB color
 * @return -1 on error, 0 on success
 */
int blink1_readPatternLineN(blink1_device *dev, ushort* fadeMillis,
                            ubyte* r, ubyte* g, ubyte* b, ubyte* ledn,
                            ubyte pos);
/**
 * Save color pattern in RAM to nonvolatile storage.
 * @note For mk2 devices only.
 * @note this doesn't actually return a proper return value, as the
 *       time it takes to write to flash actually exceeds USB timeout
 * @param dev blink1 device to command
 * @return -1 on error, 0 on success
 */
int blink1_savePattern(blink1_device *dev);

/**
 * Sets 'ledn' parameter for blink1_savePatternLine()
 * @note only works on fw 204+ devices
 */
int blink1_setLEDN( blink1_device* dev, ubyte ledn);

/**
 * @note only for devices with fw val 206+ or mk3
 */
int blink1_getStartupParams( blink1_device* dev, ubyte* bootmode,
                             ubyte* playstart, ubyte* playend, ubyte* playcount);

/**
 * @note only for devices with fw val 206+ or mk3
 * FIXME: make 'params' a struct
 */
int blink1_setStartupParams( blink1_device* dev, ubyte bootmode,
                             ubyte playstart, ubyte playend, ubyte playcount);

/**
 * Tell blink(1) to reset into bootloader.
 * mk3 devices only
 */
int blink1_bootloaderGo( blink1_device* dev );

int blink1_bootloaderLock( blink1_device* dev );

/**
 * Internal testing
 */
int blink1_getId( blink1_device *dev, ubyte** idbuf );

int blink1_testtest(blink1_device *dev, ubyte reportid);


// reads from notebuf
int blink1_writeNote( blink1_device* dev, ubyte noteid, const ubyte* notebuf);

// writes into notebuf
int blink1_readNote( blink1_device* dev, ubyte noteid, ubyte** notebuf);


char *blink1_error_msg(int errCode);

/**
 * Enable blink1-lib gamma curve.
 */
void blink1_enableDegamma();

/**
 * Disable blink1-lib gamma curve.
 * @note should probably always have it disabled
 */
void blink1_disableDegamma();
int blink1_degamma(int n);

/**
 * Using a brightness value, update an r,g,b triplet
 * Modifies r,g,b in place
 */
void blink1_adjustBrightness( ubyte brightness, ubyte* r, ubyte* g, ubyte* b);

/**
 * Simple wrapper for cross-platform millisecond delay.
 * @param delayMillis number of milliseconds to wait
 */
void blink1_sleep(ushort delayMillis);

/**
 * Vendor ID for blink1 devices.
 * @return blink1 VID
 */
int blink1_vid();  // return VID for blink(1)
/**
 * Product ID for blink1 devices.
 * @return blink1 PID
 */
int blink1_pid();  // return PID for blink(1)


/**
 * Return platform-specific USB path for given cache index.
 * @param i cache index
 * @return path string
 */
char*  blink1_getCachedPath(int i);
/**
 * Return bilnk1 serial number for given cache index.
 * @param i cache index
 * @return 8-hexdigit serial number as string
 */
char*  blink1_getCachedSerial(int i);
/**
 * Return cache index for a given platform-specific USB path.
 * @param path platform-specific path string
 * @return cache index or -1 if not found
 */
int          blink1_getCacheIndexByPath( const char* path );
/**
 * Return cache index for a given blink1 id (0-max or serial number as uint32)
 * @param i blink1 id (0-blink1_max_devices or serial as uint32)
 * @return cache index or -1 if not found
 */
int          blink1_getCacheIndexById( ushort i );
/**
 * Return cache index for a given blink1 serial number.
 * @param path platform-specific path string
 * @return cache index or -1 if not found
 */
int          blink1_getCacheIndexBySerial( const char* serial );
/**
 * Return cache index for a given blink1_device object.
 * @param dev blink1 device to lookup
 * @return cache index or -1 if not found
 */
int          blink1_getCacheIndexByDev( blink1_device* dev );
/**
 * Clear the blink1 device cache for a given device.
 * @param dev blink1 device
 * @return cache index that was cleared, or -1 if not found
 */
int          blink1_clearCacheDev( blink1_device* dev );

/**
 * Return serial number string for give blink1 device.
 * @param dev blink device to lookup
 * @return 8-hexdigit serial number string
 */
char*  blink1_getSerialForDev(blink1_device* dev);

/**
 * Return number of entries in blink1 device cache.
 * @note This is the number of devices found with blink1_enumerate()
 * @return number of cache entries
 */
int          blink1_getCachedCount();

/**
 * Returns version of device at cache index i is a mk2
 *
 * @return mk2=1, mk1=0
 */
int          blink1_isMk2ById(int i);

/**
 * Returns if given blink1_device is a mk2 or not
 * @param dev blink1 device to check
 * @return mk2=1, mk1=0
 */
int          blink1_isMk2(blink1_device* dev);

/**
 * Returns device "mk" type at cache index i
 * @return blink1Type_t (BLINK1_MK2, BLINK1_MK2, BLINK1_MK1)
 */
blink1Type_t blink1_deviceTypeById( int i );

/**
 *
 * @return blink1Type_t (BLINK1_MK2, BLINK1_MK2, BLINK1_MK1)
 */
blink1Type_t blink1_deviceType( blink1_device* dev );

/**
 * Return a string representation of the blink(1) device type
 * (e.g. "mk2" or "mk3")
 * @return const string
 */
char* blink1_deviceTypeToStr(blink1Type_t t);

/**
 *
 */
void hexdump(FILE* fp, ubyte* buffer, int len);

/**
 *
 */
int hexread(ubyte *buffer, char* str, int buflen);

/**
 *
 */
void hsbtorgb( rgb_t* rgb, ubyte* hsb );

/**
 *
 */
void parsecolor(rgb_t* color, char* colorstr);

/**
 *
 */
int parsePattern( char* str, int* repeats, patternline_t* pattern );

/**
 * printf that can be shut up
 *
 */
void msg(char* fmt, ...);

void msg_setquiet(int q);

}

/*void blink1_close( blink1_device *dev) {
	blink1_close_internal(dev);
}*/
