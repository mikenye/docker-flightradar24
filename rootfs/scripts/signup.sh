#!/usr/bin/env bash


# Regular Expressions
REGEX_PATTERN_VALID_EMAIL_ADDRESS='^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$'
REGEX_PATTERN_FR24_SHARING_KEY='^\+ Your sharing key \((\w+)\) has been configured and emailed to you for backup purposes\.'
REGEX_PATTERN_FR24_RADAR_ID='^\+ Your radar id is ([A-Za-z0-9\-]+), please include it in all email communication with us\.'


# Temp files - created in one dir
TMPDIR_FR24SIGNUP="$(mktemp -d --suffix=.fr24signup)"
TMPFILE_FR24SIGNUP_EXPECT="$TMPDIR_FR24SIGNUP/TMPFILE_FR24SIGNUP_EXPECT"
TMPFILE_FR24SIGNUP_LOG="$TMPDIR_FR24SIGNUP/TMPFILE_FR24SIGNUP_LOG"


function write_fr24_expectscript() {
    {
        echo '#!/usr/bin/env expect'
        echo 'set timeout 120'
        echo "spawn fr24feed --signup"
        echo "sleep 3"
        echo "send \"\r\""
        echo 'expect "Step 1.1 - Enter your email address (username@domain.tld)"'
        echo 'expect "$:"'
        echo "send \"${FR24_EMAIL}\r\""
        echo 'expect "Step 1.2 - If you used to feed FR24 with ADS-B data before, enter your sharing key."'
        echo 'expect "$:"'
        echo "send \"\r\""
        echo 'expect "Step 1.3 - Would you like to participate in MLAT calculations? (yes/no)$:"'
        echo "send \"yes\r\""
        echo "expect \"Step 3.A - Enter antenna's latitude (DD.DDDD)\""
        echo 'expect "$:"'
        echo "send \"${FEEDER_LAT}\r\""
        echo "expect \"Step 3.B - Enter antenna's longitude (DDD.DDDD)\""
        echo 'expect "$:"'
        echo "send \"${FEEDER_LONG}\r\""
        echo "expect \"Step 3.C - Enter antenna's altitude above the sea level (in feet)\""
        echo 'expect "$:"'
        echo "send \"${FEEDER_ALT_FT}\r\""
        # TODO - Add better error handlin
        # eg: Handle 'Validating email/location information...ERROR'
        # Need some real-world failure logs
        echo 'expect "Would you like to continue using these settings?"'
        echo 'expect "Enter your choice (yes/no)$:"'
        echo "send \"yes\r\""
        echo 'expect "Step 4.1 - Receiver selection (in order to run MLAT please use DVB-T stick with dump1090 utility bundled with fr24feed):"'
        echo 'expect "Enter your receiver type (1-7)$:"'
        echo "send \"7\r\""
        echo 'expect "Step 6 - Please select desired logfile mode:"'
        echo 'expect "Select logfile mode (0-2)$:"'
        echo "send \"0\r\""
        echo 'expect "Submitting form data...OK"'
        echo 'expect "+ Your sharing key ("'
        echo 'expect "+ Your radar id is"'
        echo 'expect "Saving settings to /etc/fr24feed.ini...OK"'
    } > "$TMPFILE_FR24SIGNUP_EXPECT"
}


# ========== MAIN SCRIPT ========== #

# Sanity checks
if ! echo "$FR24_EMAIL" | grep -P "$REGEX_PATTERN_VALID_EMAIL_ADDRESS" > /dev/null 2>&1; then
  echo "ERROR: Please set FR24_EMAIL to a valid email address"
  exit 1
fi

# write out expect script
write_fr24_expectscript

# run expect script & interpret output
if ! expect "$TMPFILE_FR24SIGNUP_EXPECT" > "$TMPFILE_FR24SIGNUP_LOG" 2>&1; then
  echo "ERROR: Problem running flightradar24 sign-up process :-("
  echo ""
  cat "$TMPFILE_FR24SIGNUP_LOG"
  exit 1
fi

# try to get sharing key
if grep -P "$REGEX_PATTERN_FR24_SHARING_KEY" "$TMPFILE_FR24SIGNUP_LOG" > /dev/null 2>&1; then
  FR24_SHARING_KEY=$(grep -P "$REGEX_PATTERN_FR24_SHARING_KEY" "$TMPFILE_FR24SIGNUP_LOG" | \
    sed -r "s/$REGEX_PATTERN_FR24_SHARING_KEY/\1/")
  echo "FR24_SHARING_KEY=$FR24_SHARING_KEY"
else
  echo "ERROR: Could not find flightradar24 sharing key :-("
  echo ""
  cat "$TMPFILE_FR24SIGNUP_LOG"
  exit 1
fi

# try to get radar ID
if grep -P "$REGEX_PATTERN_FR24_RADAR_ID" "$TMPFILE_FR24SIGNUP_LOG" > /dev/null 2>&1; then
  FR24_RADAR_ID=$(grep -P "$REGEX_PATTERN_FR24_RADAR_ID" "$TMPFILE_FR24SIGNUP_LOG" | \
    sed -r "s/$REGEX_PATTERN_FR24_RADAR_ID/\1/")
  echo "FR24_RADAR_ID=$FR24_RADAR_ID"
else
  echo "ERROR: Could not find flightradar24 radar ID :-("
  echo ""
  cat "$TMPFILE_FR24SIGNUP_LOG"
  exit 1
fi

# clean up
rm -r "$TMPDIR_FR24SIGNUP"
