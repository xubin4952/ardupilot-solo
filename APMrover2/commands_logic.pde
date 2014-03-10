/// -*- tab-width: 4; Mode: C++; c-basic-offset: 4; indent-tabs-mode: nil -*-

// forward declarations to make compiler happy
static void do_takeoff(const AP_Mission::Mission_Command& cmd);
static void do_nav_wp(const AP_Mission::Mission_Command& cmd);
static void do_wait_delay(const AP_Mission::Mission_Command& cmd);
static void do_within_distance(const AP_Mission::Mission_Command& cmd);
static void do_change_alt(const AP_Mission::Mission_Command& cmd);
static void do_change_speed(const AP_Mission::Mission_Command& cmd);
static void do_set_home(const AP_Mission::Mission_Command& cmd);
static bool verify_nav_wp(const AP_Mission::Mission_Command& cmd);

/********************************************************************************/
// Command Event Handlers
/********************************************************************************/
static bool
start_command(const AP_Mission::Mission_Command& cmd)
{
    gcs_send_text_fmt(PSTR("Executing command ID #%i"),cmd.id);

	switch(cmd.id){
		case MAV_CMD_NAV_TAKEOFF:
			do_takeoff(cmd);
			break;

		case MAV_CMD_NAV_WAYPOINT:	// Navigate to Waypoint
			do_nav_wp(cmd);
			break;

		case MAV_CMD_NAV_RETURN_TO_LAUNCH:
			do_RTL();
			break;

        // Conditional commands
		case MAV_CMD_CONDITION_DELAY:
			do_wait_delay(cmd);
			break;

		case MAV_CMD_CONDITION_DISTANCE:
			do_within_distance(cmd);
			break;

		case MAV_CMD_CONDITION_CHANGE_ALT:
			do_change_alt(cmd);
			break;

        // Do commands
		case MAV_CMD_DO_CHANGE_SPEED:
			do_change_speed(cmd);
			break;

		case MAV_CMD_DO_SET_HOME:
			do_set_home(cmd);
			break;

    	case MAV_CMD_DO_SET_SERVO:
            ServoRelayEvents.do_set_servo(cmd.p1, cmd.content.location.alt);
            break;

    	case MAV_CMD_DO_SET_RELAY:
            ServoRelayEvents.do_set_relay(cmd.p1, cmd.content.location.alt);
            break;

    	case MAV_CMD_DO_REPEAT_SERVO:
            ServoRelayEvents.do_repeat_servo(cmd.p1, cmd.content.location.alt,
                                             cmd.content.location.lat, cmd.content.location.lng);
            break;

    	case MAV_CMD_DO_REPEAT_RELAY:
            ServoRelayEvents.do_repeat_relay(cmd.p1, cmd.content.location.alt,
                                             cmd.content.location.lat);
            break;

#if CAMERA == ENABLED
        case MAV_CMD_DO_CONTROL_VIDEO:                      // Control on-board camera capturing. |Camera ID (-1 for all)| Transmission: 0: disabled, 1: enabled compressed, 2: enabled raw| Transmission mode: 0: video stream, >0: single images every n seconds (decimal)| Recording: 0: disabled, 1: enabled compressed, 2: enabled raw| Empty| Empty| Empty|
            break;

        case MAV_CMD_DO_DIGICAM_CONFIGURE:                  // Mission command to configure an on-board camera controller system. |Modes: P, TV, AV, M, Etc| Shutter speed: Divisor number for one second| Aperture: F stop number| ISO number e.g. 80, 100, 200, Etc| Exposure type enumerator| Command Identity| Main engine cut-off time before camera trigger in seconds/10 (0 means no cut-off)|
            break;

        case MAV_CMD_DO_DIGICAM_CONTROL:                    // Mission command to control an on-board camera controller system. |Session control e.g. show/hide lens| Zoom's absolute position| Zooming step value to offset zoom from the current position| Focus Locking, Unlocking or Re-locking| Shooting Command| Command Identity| Empty|
            do_take_picture();
            break;

        case MAV_CMD_DO_SET_CAM_TRIGG_DIST:
            camera.set_trigger_distance(cmd.content.location.alt);
            break;
#endif

#if MOUNT == ENABLED
		// Sets the region of interest (ROI) for a sensor set or the
		// vehicle itself. This can then be used by the vehicles control
		// system to control the vehicle attitude and the attitude of various
		// devices such as cameras.
		//    |Region of interest mode. (see MAV_ROI enum)| Waypoint index/ target ID. (see MAV_ROI enum)| ROI index (allows a vehicle to manage multiple cameras etc.)| Empty| x the location of the fixed ROI (see MAV_FRAME)| y| z|
		case MAV_CMD_DO_SET_ROI:
#if 0
            // not supported yet
			camera_mount.set_roi_cmd();
#endif
			break;

		case MAV_CMD_DO_MOUNT_CONFIGURE:	// Mission command to configure a camera mount |Mount operation mode (see MAV_CONFIGURE_MOUNT_MODE enum)| stabilize roll? (1 = yes, 0 = no)| stabilize pitch? (1 = yes, 0 = no)| stabilize yaw? (1 = yes, 0 = no)| Empty| Empty| Empty|
			camera_mount.configure_cmd();
			break;

		case MAV_CMD_DO_MOUNT_CONTROL:		// Mission command to control a camera mount |pitch(deg*100) or lat, depending on mount mode.| roll(deg*100) or lon depending on mount mode| yaw(deg*100) or alt (in cm) depending on mount mode| Empty| Empty| Empty| Empty|
			camera_mount.control_cmd();
			break;
#endif

		default:
		    // return false for unhandled commands
		    return false;
	}

	// if we got this far we must have been successful
	return true;
}

static void exit_mission()
{
	gcs_send_text_fmt(PSTR("No commands - setting HOLD"));
    set_mode(HOLD);
}

/********************************************************************************/
// Verify command Handlers
//      Returns true if command complete
/********************************************************************************/

static bool verify_command(const AP_Mission::Mission_Command& cmd)
{
	switch(cmd.id) {

		case MAV_CMD_NAV_TAKEOFF:
			return verify_takeoff();

		case MAV_CMD_NAV_WAYPOINT:
			return verify_nav_wp(cmd);

		case MAV_CMD_NAV_RETURN_TO_LAUNCH:
			return verify_RTL();

        case MAV_CMD_CONDITION_DELAY:
            return verify_wait_delay();
            break;

        case MAV_CMD_CONDITION_DISTANCE:
            return verify_within_distance();
            break;

        case MAV_CMD_CONDITION_CHANGE_ALT:
            return verify_change_alt();
            break;

        default:
            gcs_send_text_P(SEVERITY_HIGH,PSTR("verify_conditon: Unsupported command"));
            return true;
            break;
	}
    return false;
}

/********************************************************************************/
//  Nav (Must) commands
/********************************************************************************/

static void do_RTL(void)
{
    prev_WP.content.location = current_loc;
	control_mode 	= RTL;
	next_WP.content.location = home;
}

static void do_takeoff(const AP_Mission::Mission_Command& cmd)
{
	set_next_WP(cmd);
}

static void do_nav_wp(const AP_Mission::Mission_Command& cmd)
{
	set_next_WP(cmd);
}

/********************************************************************************/
//  Verify Nav (Must) commands
/********************************************************************************/
static bool verify_takeoff()
{  return true;
}

static bool verify_nav_wp(const AP_Mission::Mission_Command& cmd)
{
    if ((wp_distance > 0) && (wp_distance <= g.waypoint_radius)) {
        gcs_send_text_fmt(PSTR("Reached Waypoint #%i dist %um"),
                          (unsigned)cmd.index,
                          (unsigned)get_distance(current_loc, next_WP.content.location));
        return true;
    }

    // have we gone past the waypoint?
    if (location_passed_point(current_loc, prev_WP.content.location, next_WP.content.location)) {
        gcs_send_text_fmt(PSTR("Passed Waypoint #%i dist %um"),
                          (unsigned)cmd.index,
                          (unsigned)get_distance(current_loc, next_WP.content.location));
        return true;
    }

    return false;
}

static bool verify_RTL()
{
	if (wp_distance <= g.waypoint_radius) {
		gcs_send_text_P(SEVERITY_LOW,PSTR("Reached home"));
                rtl_complete = true;
		return true;
	}

    // have we gone past the waypoint?
    if (location_passed_point(current_loc, prev_WP.content.location, next_WP.content.location)) {
        gcs_send_text_fmt(PSTR("Reached Home dist %um"),
                          (unsigned)get_distance(current_loc, next_WP.content.location));
        return true;
    }

    return false;
}

/********************************************************************************/
//  Condition (May) commands
/********************************************************************************/

static void do_wait_delay(const AP_Mission::Mission_Command& cmd)
{
	condition_start = millis();
	condition_value  = cmd.content.location.lat * 1000;	// convert to milliseconds
}

static void do_change_alt(const AP_Mission::Mission_Command& cmd)
{
	condition_rate		= abs((int)cmd.content.location.lat);
	condition_value 	= cmd.content.location.alt;
	if(condition_value < current_loc.alt) condition_rate = -condition_rate;
	next_WP.content.location.alt = condition_value;								// For future nav calculations
}

static void do_within_distance(const AP_Mission::Mission_Command& cmd)
{
	condition_value  = cmd.content.location.lat;
}

/********************************************************************************/
// Verify Condition (May) commands
/********************************************************************************/

static bool verify_wait_delay()
{
	if ((uint32_t)(millis() - condition_start) > (uint32_t)condition_value){
		condition_value 	= 0;
		return true;
	}
	return false;
}

static bool verify_change_alt()
{
	if( (condition_rate>=0 && current_loc.alt >= condition_value) || (condition_rate<=0 && current_loc.alt <= condition_value)) {
		condition_value = 0;
		return true;
	}
	return false;
}

static bool verify_within_distance()
{
	if (wp_distance < condition_value){
		condition_value = 0;
		return true;
	}
	return false;
}

/********************************************************************************/
//  Do (Now) commands
/********************************************************************************/

static void do_change_speed(const AP_Mission::Mission_Command& cmd)
{
	switch (cmd.p1)
	{
		case 0:
			if (cmd.content.location.alt > 0) {
				g.speed_cruise.set(cmd.content.location.alt);
                gcs_send_text_fmt(PSTR("Cruise speed: %.1f"), g.speed_cruise.get());
            }
			break;
	}

	if (cmd.content.location.lat > 0) {
		g.throttle_cruise.set(cmd.content.location.lat);
        gcs_send_text_fmt(PSTR("Cruise throttle: %.1f"), g.throttle_cruise.get());
    }
}

static void do_set_home(const AP_Mission::Mission_Command& cmd)
{
	if(cmd.p1 == 1 && have_position) {
		init_home();
	} else {
        ahrs.set_home(cmd.content.location.lat, cmd.content.location.lng, cmd.content.location.alt);
		home_is_set = true;
	}
}

// do_take_picture - take a picture with the camera library
static void do_take_picture()
{
#if CAMERA == ENABLED
    camera.trigger_pic();
    if (should_log(MASK_LOG_CAMERA)) {
        Log_Write_Camera();
    }
#endif
}
