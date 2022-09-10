DROP FUNCTION IF EXISTS j1970;
DROP FUNCTION IF EXISTS j2000;
DROP FUNCTION IF EXISTS obliquity;
DROP FUNCTION IF EXISTS to_julian;
DROP FUNCTION IF EXISTS from_julian;
DROP FUNCTION IF EXISTS to_days;
DROP FUNCTION IF EXISTS right_ascension;
DROP FUNCTION IF EXISTS declination;
DROP FUNCTION IF EXISTS azimuth;
DROP FUNCTION IF EXISTS altitude;
DROP FUNCTION IF EXISTS sidereal_time;
DROP FUNCTION IF EXISTS solar_mean_anomaly;
DROP FUNCTION IF EXISTS ecliptic_longitude;
DROP FUNCTION IF EXISTS juliancycle;
DROP FUNCTION IF EXISTS approximate_transit;
DROP FUNCTION IF EXISTS solar_transit_j;
DROP FUNCTION IF EXISTS hour_angle;
DROP FUNCTION IF EXISTS observer_angle;
DROP FUNCTION IF EXISTS time_for_horizon_angles;
DROP FUNCTION IF EXISTS get_sun_times;

CREATE OR REPLACE FUNCTION fmod(
    dividend double precision,
    divisor double precision
) RETURNS double precision
    IMMUTABLE AS
$$
BEGIN
    RETURN dividend - floor(dividend / divisor) * divisor;
END;
$$ LANGUAGE plpgsql;

-- Constant for Julian day '1970-01-01 12:00:00 UTC' --> https://en.wikipedia.org/wiki/Julian_day
CREATE OR REPLACE FUNCTION j1970() RETURNS int AS
$$
BEGIN
    RETURN 2440588;
END;
$$ LANGUAGE plpgsql;

-- Constant for Julian date '2020-01-01 12:00:00 UTC' --> https://en.wikipedia.org/wiki/Julian_day
CREATE OR REPLACE FUNCTION j2000() RETURNS int AS
$$
BEGIN
    RETURN 2451545;
END;
$$ LANGUAGE plpgsql;

-- Constant for the obliquity of Earth or Earth's axial tilt --> https://en.wikipedia.org/wiki/Axial_tilt#Earth
CREATE OR REPLACE FUNCTION obliquity() RETURNS double precision AS
$$
BEGIN
    RETURN radians(23.4397);
END;
$$ LANGUAGE plpgsql;

-- Converts an epoch timestamp to Julian date
CREATE OR REPLACE FUNCTION to_julian(ts double precision) RETURNS double precision AS
$$
BEGIN
    -- RETURN ts / 86400 - 0.5 + j1970();
    RETURN ts / 86400 - 0.5 + 2440588;
END;
$$ LANGUAGE plpgsql;

-- Converts a Julian date to epoch timestamp
CREATE OR REPLACE FUNCTION from_julian(j double precision) RETURNS double precision AS
$$
BEGIN
    -- RETURN (j + 0.5 - j1970()) * 86400;
    RETURN (j + 0.5 - 2440588) * 86400;
END;
$$ LANGUAGE plpgsql;

-- Calculates the number of days since '2020-01-01 12:00:00 UTC'
CREATE OR REPLACE FUNCTION to_days(ts double precision) RETURNS double precision AS
$$
BEGIN
    -- RETURN to_julian(ts) - j2000();
    RETURN to_julian(ts) - 2451545;
END;
$$ LANGUAGE plpgsql;

-- Calculates the right ascension for a given longitude (|) and latitude (-) --> https://en.wikipedia.org/wiki/Right_ascension
CREATE OR REPLACE FUNCTION right_ascension(longitude double precision, latitude double precision) RETURNS double precision AS
$$
BEGIN
    RETURN atan2(sin(longitude) * cos(obliquity()) - tan(latitude) * sin(obliquity()), cos(longitude));
END;
$$ LANGUAGE plpgsql;

-- Calculates the declination for a given longitude (|) and latitude (-) --> https://en.wikipedia.org/wiki/Declination
CREATE OR REPLACE FUNCTION declination(longitude double precision, latitude double precision) RETURNS double precision AS
$$
BEGIN
    RETURN asin(sin(latitude) * cos(obliquity()) + cos(latitude) * sin(obliquity()) * sin(longitude));
END;
$$ LANGUAGE plpgsql;

-- Calculates the azimuth for given sideral time h, phi and declination --> https://en.wikipedia.org/wiki/Azimuth
CREATE OR REPLACE FUNCTION azimuth(h double precision, phi double precision, decl double precision) RETURNS double precision AS
$$
BEGIN
    RETURN atan2(sin(h), cos(h) * sin(phi) - tan(decl) * cos(phi));
END;
$$ LANGUAGE plpgsql;

-- Calculates the altitude for given sideral time h, phi and declination --> https://en.wikipedia.org/wiki/Horizontal_coordinate_system
CREATE OR REPLACE FUNCTION altitude(h double precision, phi double precision, decl double precision) RETURNS double precision AS
$$
BEGIN
    RETURN asin(sin(phi) * sin(decl) + cos(phi) * cos(decl) * cos(h));
END;
$$ LANGUAGE plpgsql;

-- Calculates the sidereal time for given day and longitude --> https://en.wikipedia.org/wiki/Sidereal_time
CREATE OR REPLACE FUNCTION sidereal_time(day double precision, longidtude_rad double precision) RETURNS double precision AS
$$
BEGIN
    RETURN pi() / 180 * (280.16 + 360.9856235 * day) - longidtude_rad;
END;
$$ LANGUAGE plpgsql;

-- Calculates the solar mean anomaly for a given day --> https://en.wikipedia.org/wiki/Mean_anomaly
CREATE OR REPLACE FUNCTION solar_mean_anomaly(day double precision) RETURNS double precision AS
$$
BEGIN
    RETURN pi() / 180 * (357.5291 + 0.98560028 * day);
END;
$$ LANGUAGE plpgsql;

-- Calculates the ecliptic longitude for a given mean anomaly --> https://en.wikipedia.org/wiki/Ecliptic_coordinate_system#Spherical_coordinates
CREATE OR REPLACE FUNCTION ecliptic_longitude(mean_anomaly double precision) RETURNS double precision AS
$$
DECLARE
    center     double precision;
    perihelion double precision;
BEGIN
    center = pi() / 180 * (1.9148 * sin(mean_anomaly) + 0.02 * sin(2 * mean_anomaly) +
                           0.0003 * sin(3 * mean_anomaly)); -- equation of center
    perihelion = pi() / 180 * 102.9372; -- perihelion of the Earth

    RETURN mean_anomaly + center + perihelion + pi();
END;
$$ LANGUAGE plpgsql;

-- Calculates the julian cycle for given day and longitude
CREATE OR REPLACE FUNCTION juliancycle(day double precision, longitude_rad double precision) RETURNS double precision AS
$$
BEGIN
    RETURN round(day - 0.0009 - longitude_rad / (2 * pi()));
END;
$$ LANGUAGE plpgsql;

-- Calculates the approximate transit for
CREATE OR REPLACE FUNCTION approximate_transit(ht double precision, lw double precision, n double precision) RETURNS double precision AS
$$
BEGIN
    RETURN 0.0009 + (ht + lw) / (2 * pi()) + n;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION solar_transit_j(ds double precision, m double precision, l double precision) RETURNS double precision AS
$$
BEGIN
    -- RETURN j2000() + ds + 0.0053 * sin(m) - 0.0069 * sin(2 * l);
    RETURN 2451545 + ds + 0.0053 * sin(m) - 0.0069 * sin(2 * l);
END;
$$ LANGUAGE plpgsql;

----------------------------------------------------------------------

CREATE OR REPLACE FUNCTION hour_angle(h double precision, phi double precision, d double precision) RETURNS double precision AS
$$
DECLARE
    result double precision;
BEGIN
    result = acos((sin(h) - sin(phi) * sin(d)) / (cos(phi) * cos(d)));
    RETURN result;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION observer_angle(height double precision) RETURNS double precision AS
$$
BEGIN
    RETURN (-2.076 * sqrt(height)) / 60.0;
END;
$$ LANGUAGE plpgsql;

-- returns set time for the given sun altitude
CREATE OR REPLACE FUNCTION get_set_j(h double precision,
                                     lw double precision,
                                     phi double precision,
                                     decl double precision,
                                     n double precision,
                                     m double precision,
                                     l double precision) RETURNS double precision AS
$$
DECLARE
    w double precision;
    a double precision;
BEGIN
    w = hour_angle(h, phi, decl);
    a = approximate_transit(w, lw, n);
    RETURN solar_transit_j(a, m, l);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION sun_coordinates(d double precision,
                                           OUT decl double precision,
                                           OUT ra double precision) RETURNS record AS
$$
DECLARE
    m double precision;
    l double precision;
BEGIN
    m = solar_mean_anomaly(d);
    l = ecliptic_longitude(m);

    decl = declination(l, 0);
    ra = right_ascension(l, 0);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_sun_position(ts timestamp WITH TIME ZONE,
                                            lat double precision,
                                            lng double precision,
                                            OUT azimuth double precision,
                                            OUT altitude double precision) RETURNS record AS
$$
DECLARE
    date double precision;
    lw   double precision;
    phi  double precision;
    d    double precision;
    decl double precision;
    ra   double precision;
    h    double precision;
BEGIN
    date = extract('epoch' FROM ts)::double precision;

    lw = pi() / 180 * -lng;
    phi = pi() / 180 * lat;
    d = to_days(date);

    SELECT * INTO decl, ra FROM sun_coordinates(d);
    h = sidereal_time(d, lw) - ra;

    azimuth = azimuth(h, phi, decl);
    altitude = altitude(h, phi, decl);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION time_for_horizon_angles(angle double precision,
                                                   jnoon double precision,
                                                   lw double precision,
                                                   dh double precision,
                                                   phi double precision,
                                                   decl double precision,
                                                   n double precision,
                                                   m double precision,
                                                   l double precision,
                                                   OUT risetime double precision,
                                                   OUT settime double precision) RETURNS record AS
$$
DECLARE
    h0    double precision;
    jset  double precision;
    jrise double precision;
BEGIN
    h0 = (angle + dh) * pi() / 180;
    jset = get_set_j(h0, lw, phi, decl, n, m, l);
    jrise = jnoon - (jset - jnoon);

    risetime = from_julian(jrise);
    settime = from_julian(jset);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_sun_times(ts timestamp WITH TIME ZONE,
                                         lat double precision,
                                         lng double precision,
                                         height double precision)
    RETURNS table
            (
                event  varchar,
                "time" timestamp WITH TIME ZONE,
                az     double precision,
                alt    double precision
            )
AS
$$
DECLARE
    date      double precision;
    lw        double precision;
    phi       double precision;
    dh        double precision;
    d         double precision;
    n         double precision;
    ds        double precision;
    m         double precision;
    l         double precision;
    decl      double precision;
    j_noon    double precision;
    rec       RECORD;
    rise_time double precision;
    set_time  double precision;
BEGIN
    date = extract('epoch' FROM ts)::double precision;

    lw = pi() / 180 * -lng;
    phi = pi() / 180 * lat;
    dh = observer_angle(height);
    d = to_days(date);
    n = juliancycle(d, lw);
    ds = approximate_transit(0, lw, n);
    m = solar_mean_anomaly(ds);
    l = ecliptic_longitude(m);
    decl = declination(l, 0);
    j_noon = solar_transit_j(ds, m, l);

    CREATE TEMP TABLE temp_solartimes
    (
        angle double precision,
        start varchar,
        "end" varchar
    );

    INSERT INTO temp_solartimes(angle, start, "end")
    VALUES (-0.833, 'sunrise', 'sunset'),
           (-0.3, 'sunriseEnd', 'sunsetStart'),
           (-6, 'dawn', 'dusk'),
           (-12, 'nauticalDawn', 'nauticalDusk'),
           (-18, 'nightEnd', 'night'),
           (6, 'goldenHourEnd', 'goldenHour');

    event := 'solarNoon';
    time := to_timestamp(from_julian(j_noon)) AT TIME ZONE 'UTC';
    SELECT * INTO az, alt FROM get_sun_position(time, lat, lng);
    RETURN NEXT;

    event := 'nadir';
    time := to_timestamp(from_julian(j_noon - 0.5)) AT TIME ZONE 'UTC';
    SELECT * INTO az, alt FROM get_sun_position(time, lat, lng);
    RETURN NEXT;

    FOR rec IN SELECT angle, start, "end" FROM temp_solartimes
        LOOP
            BEGIN
                SELECT *
                INTO rise_time, set_time
                FROM time_for_horizon_angles(rec.angle, j_noon, lw, dh, phi, decl, n, m, l) AS x;
            EXCEPTION
                WHEN OTHERS THEN RAISE INFO 'No valid values for % and %. That is totally fine and just how earth works :-)', rec.start, rec."end";
                rise_time = NULL;
                set_time = NULL;
            END;

            event := rec.start;
            time := to_timestamp(rise_time) AT TIME ZONE 'UTC';
            SELECT * INTO az, alt FROM get_sun_position(time, lat, lng);

            RETURN NEXT;

            event := rec."end";
            time := to_timestamp(set_time) AT TIME ZONE 'UTC';
            SELECT * INTO az, alt FROM get_sun_position(time, lat, lng);
            RETURN NEXT;
        END LOOP;

    DROP TABLE temp_solartimes;
END ;
$$ LANGUAGE plpgsql;
--

EXPLAIN ANALYZE VERBOSE
SELECT x.generate_series::date             AS "date",
       z.event                             AS "event",
       z.time AT TIME ZONE 'Europe/Berlin' AS "time",
       fmod(degrees(z.az) - 180, 360)      AS "azimuth",
       degrees(z.az)                       AS "azimuth_rel_s",
       degrees(z.alt)                      AS "altitude"
FROM (SELECT * FROM generate_series('2022-01-01 12:00'::timestamp, '2022-12-31 12:00', '1 day')) x
   , get_sun_times(x.generate_series, 51, 6, 0) z
WHERE z.event IN ('sunrise', 'sunset', 'solarNoon')
ORDER BY z.time

