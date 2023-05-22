DROP FUNCTION IF EXISTS sc_j1970;
DROP FUNCTION IF EXISTS sc_j2000;
DROP FUNCTION IF EXISTS sc_obliquity;
DROP FUNCTION IF EXISTS sc_to_julian;
DROP FUNCTION IF EXISTS sc_from_julian;
DROP FUNCTION IF EXISTS sc_to_days;
DROP FUNCTION IF EXISTS sc_right_ascension;
DROP FUNCTION IF EXISTS sc_declination;
DROP FUNCTION IF EXISTS sc_azimuth;
DROP FUNCTION IF EXISTS sc_altitude;
DROP FUNCTION IF EXISTS sc_sidereal_time;
DROP FUNCTION IF EXISTS sc_solar_mean_anomaly;
DROP FUNCTION IF EXISTS sc_ecliptic_longitude;
DROP FUNCTION IF EXISTS sc_juliancycle;
DROP FUNCTION IF EXISTS sc_approximate_transit;
DROP FUNCTION IF EXISTS sc_solar_transit_j;
DROP FUNCTION IF EXISTS sc_hour_angle;
DROP FUNCTION IF EXISTS sc_observer_angle;
DROP FUNCTION IF EXISTS sc_time_for_horizon_angles;
DROP FUNCTION IF EXISTS sc_get_set_j;
DROP FUNCTION IF EXISTS sc_sun_coordinates;
DROP FUNCTION IF EXISTS get_sun_times;
DROP FUNCTION IF EXISTS get_sun_position;

CREATE OR REPLACE FUNCTION fmod(
    dividend double precision,
    divisor double precision
) RETURNS double precision AS
$$
BEGIN
    RETURN dividend - floor(dividend / divisor) * divisor;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

/**
 * Retrieve the Julian epoch value.
 *
 * @returns {int} - The Julian epoch value.
 */ CREATE OR REPLACE FUNCTION sc_j1970() RETURNS int AS
$$
BEGIN
    RETURN 2440588;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

/**
 * Retrieve the Julian day for the J2000 epoch.
 *
 * @returns {int} - The Julian day for the J2000 epoch.
 */ CREATE OR REPLACE FUNCTION sc_j2000() RETURNS int AS
$$
BEGIN
    RETURN 2451545;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

/**
 * Retrieve the obliquity of the Earth's axis.
 *
 * @returns {double precision} - The obliquity of the Earth's axis in radians.
 *
 * @see [Obliquity of the ecliptic](https://en.wikipedia.org/wiki/Obliquity_of_the_ecliptic)
 */ CREATE OR REPLACE FUNCTION sc_obliquity() RETURNS double precision AS
$$
BEGIN
    RETURN radians(23.4397);
END;
$$ LANGUAGE plpgsql IMMUTABLE;

/**
 * Calculate the Julian day for a given timestamp.
 *
 * @param {double precision} timestamp - The timestamp value to be converted to Julian day.
 * @returns {double precision} - The corresponding Julian day.
 */ CREATE OR REPLACE FUNCTION sc_to_julian("timestamp" double precision) RETURNS double precision AS
$$
BEGIN
    -- RETURN ts / 86400 - 0.5 + j1970();
    RETURN timestamp / 86400 - 0.5 + 2440588;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

/**
 * Convert a Julian day value to a corresponding timestamp.
 *
 * @param {double precision} j - The Julian day value to be converted.
 * @returns {double precision} - The corresponding timestamp value.
 */ CREATE OR REPLACE FUNCTION sc_from_julian(j double precision) RETURNS double precision AS
$$
BEGIN
    RETURN (j + 0.5 - sc_j1970()) * 86400;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

/**
 * Calculate the number of days elapsed between a given timestamp and the J2000 epoch.
 *
 * @param {double precision} timestamp - The timestamp value.
 * @returns {double precision} - The number of days elapsed.
 */ CREATE OR REPLACE FUNCTION sc_to_days("timestamp" double precision) RETURNS double precision AS
$$
BEGIN
    -- RETURN to_julian(ts) - j2000();
    RETURN sc_to_julian("timestamp") - 2451545;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

/**
 * Calculate the right ascension for a given longitude (|) and latitude (-)
 *
 * @param {double precision} longitude - The longitude value in radians.
 * @param {double precision} latitude - The latitude value in radians.
 * @returns {double precision} - The calculated right ascension.
 */ CREATE OR REPLACE FUNCTION sc_right_ascension(longitude double precision, latitude double precision) RETURNS double precision AS
$$
BEGIN
    RETURN atan2(sin(longitude) * cos(sc_obliquity()) - tan(latitude) * sin(sc_obliquity()), cos(longitude));
END;
$$ LANGUAGE plpgsql IMMUTABLE;

/**
 * Calculate the declination for a given longitude and latitude.
 *
 * @param {double precision} longitude - The longitude value in radians.
 * @param {double precision} latitude - The latitude value in radians.
 * @returns {double precision} - The calculated declination.
 */ CREATE OR REPLACE FUNCTION sc_declination(longitude double precision, latitude double precision) RETURNS double precision AS
$$
BEGIN
    RETURN asin(sin(latitude) * cos(sc_obliquity()) + cos(latitude) * sin(sc_obliquity()) * sin(longitude));
END;
$$ LANGUAGE plpgsql IMMUTABLE;

/**
 * Calculate the azimuth for a given hour angle, observer latitude, and declination.
 *
 * @param {double precision} hourAngle - The hour angle value in radians.
 * @param {double precision} observerLatitude - The observer latitude value in radians.
 * @param {double precision} declination - The declination value in radians.
 * @returns {double precision} - The calculated azimuth.
 */ CREATE OR REPLACE FUNCTION sc_azimuth(hourangle double precision, observerlatitude double precision,
                                          declination double precision) RETURNS double precision AS
$$
BEGIN
    RETURN atan2(sin(hourangle), cos(hourangle) * sin(observerlatitude) - tan(declination) * cos(observerlatitude));
END;
$$ LANGUAGE plpgsql IMMUTABLE;

/**
 * Calculate the altitude for a given hour angle, observer latitude, and declination.
 *
 * @param {double precision} hourAngle - The hour angle value in radians.
 * @param {double precision} observerLatitude - The observer latitude value in radians.
 * @param {double precision} declination - The declination value in radians.
 * @returns {double precision} - The calculated altitude.
 */ CREATE OR REPLACE FUNCTION sc_altitude(hourangle double precision, observerlatitude double precision,
                                           declination double precision) RETURNS double precision AS
$$
BEGIN
    RETURN asin(sin(observerlatitude) * sin(declination) + cos(observerlatitude) * cos(declination) * cos(hourangle));
END;
$$ LANGUAGE plpgsql IMMUTABLE;

/**
 * Calculate the sidereal time for a given day and longitude. https://en.wikipedia.org/wiki/Sidereal_time
 *
 * @param {double precision} day - The day value.
 * @param {double precision} longitude - The longitude value in radians.
 * @returns {double precision} - The calculated sidereal time.
 */ CREATE OR REPLACE FUNCTION sc_sidereal_time(day double precision, longidtude double precision) RETURNS double precision AS
$$
BEGIN
    RETURN pi() / 180 * (280.16 + 360.9856235 * day) - longidtude;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

/**
 * Calculate the solar mean anomaly for a given day. https://en.wikipedia.org/wiki/Mean_anomaly
 *
 * @param {double precision} day - The day value.
 * @returns {double precision} - The calculated solar mean anomaly.
 */ CREATE OR REPLACE FUNCTION sc_solar_mean_anomaly(day double precision) RETURNS double precision AS
$$
BEGIN
    RETURN pi() / 180 * (357.5291 + 0.98560028 * day);
END;
$$ LANGUAGE plpgsql IMMUTABLE;

/**
 * Calculate the ecliptic longitude for a given mean anomaly. https://en.wikipedia.org/wiki/Ecliptic_coordinate_system#Spherical_coordinates
 *
 * @param {double precision} meanAnomaly - The mean anomaly value in radians.
 * @returns {double precision} - The calculated ecliptic longitude.
 */ CREATE OR REPLACE FUNCTION sc_ecliptic_longitude(mean_anomaly double precision) RETURNS double precision AS
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
$$ LANGUAGE plpgsql IMMUTABLE;

/**
 * Calculate the Julian cycle for a given day and longitude.
 *
 * @param {double precision} day - The day value.
 * @param {double precision} longitude - The longitude value in radians.
 * @returns {double precision} - The calculated Julian cycle.
 */ CREATE OR REPLACE FUNCTION sc_juliancycle(day double precision, longitude double precision) RETURNS double precision AS
$$
BEGIN
    RETURN round(day - 0.0009 - longitude / (2 * pi()));
END;
$$ LANGUAGE plpgsql IMMUTABLE;

/**
 * Calculate the approximate transit time for a given hour time, longitude, and correction factor.
 *
 * @param {double precision} hourTime - The hour time value.
 * @param {double precision} longitude - The longitude value in radians.
 * @param {double precision} correctionFactor - The correction factor value.
 * @returns {double precision} - The calculated approximate transit time.
 */ CREATE OR REPLACE FUNCTION sc_approximate_transit(hourtime double precision, longitude double precision,
                                                      correctionfactor double precision) RETURNS double precision AS
$$
BEGIN
    RETURN 0.0009 + (hourtime + longitude) / (2 * pi()) + correctionfactor;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

/**
 * Calculate the Julian date of solar transit for a given delta time, mean anomaly, and longitude.
 *
 * @param {double precision} deltaTime - The delta time value.
 * @param {double precision} meanAnomaly - The mean anomaly value in radians.
 * @param {double precision} longitude - The longitude value in radians.
 * @returns {double precision} - The calculated Julian date of solar transit.
 */ CREATE OR REPLACE FUNCTION sc_solar_transit_j(deltatime double precision, meananomaly double precision,
                                                  longitude double precision) RETURNS double precision AS
$$
BEGIN
    -- RETURN j2000() + ds + 0.0053 * sin(m) - 0.0069 * sin(2 * l);
    RETURN 2451545 + deltatime + 0.0053 * sin(meananomaly) - 0.0069 * sin(2 * longitude);
END;
$$ LANGUAGE plpgsql IMMUTABLE;

----------------------------------------------------------------------

/**
 * Calculate the hour angle for a given altitude, latitude, and declination.
 *
 * @param {double precision} altitude - The altitude value in radians.
 * @param {double precision} latitude - The latitude value in radians.
 * @param {double precision} declination - The declination value in radians.
 * @returns {double precision} - The calculated hour angle.
 */ CREATE OR REPLACE FUNCTION sc_hour_angle(altitude double precision, latitude double precision,
                                             d double precision) RETURNS double precision AS
$$
DECLARE
    result double precision;
BEGIN
    result = acos((sin(altitude) - sin(latitude) * sin(d)) / (cos(latitude) * cos(d)));
    RETURN result;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

CREATE OR REPLACE FUNCTION sc_observer_angle(height double precision) RETURNS double precision AS
$$
BEGIN
    RETURN (-2.076 * sqrt(height)) / 60.0;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- returns set time for the given sun altitude
CREATE OR REPLACE FUNCTION sc_get_set_j(h double precision,
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
    w = sc_hour_angle(h, phi, decl);
    a = sc_approximate_transit(w, lw, n);
    RETURN sc_solar_transit_j(a, m, l);
END;
$$ LANGUAGE plpgsql IMMUTABLE;

CREATE OR REPLACE FUNCTION sc_sun_coordinates(d double precision,
                                              OUT decl double precision,
                                              OUT ra double precision) RETURNS record AS
$$
DECLARE
    m double precision;
    l double precision;
BEGIN
    m = sc_solar_mean_anomaly(d);
    l = sc_ecliptic_longitude(m);

    decl = sc_declination(l, 0);
    ra = sc_right_ascension(l, 0);
END;
$$ LANGUAGE plpgsql IMMUTABLE;

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
    d = sc_to_days(date);

    SELECT * INTO decl, ra FROM sc_sun_coordinates(d);
    h = sc_sidereal_time(d, lw) - ra;

    azimuth = sc_azimuth(h, phi, decl);
    altitude = sc_altitude(h, phi, decl);
END;
$$ LANGUAGE plpgsql IMMUTABLE;

CREATE OR REPLACE FUNCTION sc_time_for_horizon_angles(angle double precision,
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
    jset = sc_get_set_j(h0, lw, phi, decl, n, m, l);
    jrise = jnoon - (jset - jnoon);

    risetime = sc_from_julian(jrise);
    settime = sc_from_julian(jset);
END;
$$ LANGUAGE plpgsql IMMUTABLE;

CREATE OR REPLACE FUNCTION get_sun_times(ts timestamp WITH TIME ZONE,
                                         lat double precision,
                                         lng double precision,
                                         height double precision)
    RETURNS table
            (
                event  varchar,
                "time" timestamp WITH TIME ZONE
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
    dh = sc_observer_angle(height);
    d = sc_to_days(date);
    n = sc_juliancycle(d, lw);
    ds = sc_approximate_transit(0, lw, n);
    m = sc_solar_mean_anomaly(ds);
    l = sc_ecliptic_longitude(m);
    decl = sc_declination(l, 0);
    j_noon = sc_solar_transit_j(ds, m, l);

    event := 'solarNoon';
    time := to_timestamp(sc_from_julian(j_noon)) AT TIME ZONE 'UTC';
    RETURN NEXT;

    event := 'nadir';
    time := to_timestamp(sc_from_julian(j_noon - 0.5)) AT TIME ZONE 'UTC';
    RETURN NEXT;

    FOR rec IN SELECT angle, start, "end"
               FROM (VALUES (-0.833, 'sunrise', 'sunset'),
                            (-0.3, 'sunriseEnd', 'sunsetStart'),
                            (-6, 'dawn', 'dusk'),
                            (-12, 'nauticalDawn', 'nauticalDusk'),
                            (-18, 'nightEnd', 'night'),
                            (6, 'goldenHourEnd', 'goldenHour')) x(angle, start, "end")
        LOOP
            BEGIN
                SELECT risetime, settime
                INTO rise_time, set_time
                FROM sc_time_for_horizon_angles(rec.angle, j_noon, lw, dh, phi, decl, n, m, l) AS x;
            EXCEPTION
                WHEN OTHERS THEN RAISE INFO 'No valid values for % and %. That is totally fine and just how earth works :-)', rec.start, rec."end";
                rise_time = NULL;
                set_time = NULL;
            END;

            event := rec.start;
            time := to_timestamp(rise_time) AT TIME ZONE 'UTC';
            RETURN NEXT;

            event := rec."end";
            time := to_timestamp(set_time) AT TIME ZONE 'UTC';
            RETURN NEXT;
        END LOOP;
END ;
$$ LANGUAGE plpgsql IMMUTABLE;
--

CREATE OR REPLACE FUNCTION get_sun_times2(ts timestamp WITH TIME ZONE,
                                          lat double precision,
                                          lng double precision,
                                          height double precision)
    RETURNS TABLE
            (
                event  varchar,
                "time" timestamp WITH TIME ZONE
            )
AS
$$
DECLARE
    date   double precision;
    lw     double precision;
    phi    double precision;
    dh     double precision;
    d      double precision;
    n      double precision;
    ds     double precision;
    m      double precision;
    l      double precision;
    decl   double precision;
    j_noon double precision;
BEGIN
    date = extract('epoch' FROM ts)::double precision;

    lw = pi() / 180 * -lng;
    phi = pi() / 180 * lat;
    dh = sc_observer_angle(height);
    d = sc_to_days(date);
    n = sc_juliancycle(d, lw);
    ds = sc_approximate_transit(0, lw, n);
    m = sc_solar_mean_anomaly(ds);
    l = sc_ecliptic_longitude(m);
    decl = sc_declination(l, 0);
    j_noon = sc_solar_transit_j(ds, m, l);

    RETURN QUERY SELECT 'solarNoon' AS event, to_timestamp(sc_from_julian(j_noon)) AT TIME ZONE 'UTC' AS "time"
                 UNION ALL
                 SELECT 'nadir', to_timestamp(sc_from_julian(j_noon - 0.5)) AT TIME ZONE 'UTC'
                 UNION ALL
                 SELECT rec.start, to_timestamp(rise_time) AT TIME ZONE 'UTC'
                 FROM (VALUES (-0.833, 'sunrise', 'sunset'),
                              (-0.3, 'sunriseEnd', 'sunsetStart'),
                              (-6, 'dawn', 'dusk'),
                              (-12, 'nauticalDawn', 'nauticalDusk'),
                              (-18, 'nightEnd', 'night'),
                              (6, 'goldenHourEnd', 'goldenHour')) rec(angle, start, "end")
                          LEFT JOIN LATERAL sc_time_for_horizon_angles(rec.angle, j_noon, lw, dh, phi, decl, n, m,
                                                                       l) AS x(rise_time, set_time) ON TRUE
                 WHERE rise_time IS NOT NULL
                   AND set_time IS NOT NULL;

EXCEPTION
    WHEN OTHERS THEN RAISE INFO 'No valid values for % and %. That is totally fine and just how earth works :-)', 1, 2;
    RETURN;
END ;
$$ LANGUAGE plpgsql IMMUTABLE;


EXPLAIN ANALYZE VERBOSE
SELECT x.generate_series::date AS "date", z.event AS "event", z.time AT TIME ZONE 'Europe/Berlin' AS "time"
FROM (SELECT * FROM generate_series('2022-01-01 12:00'::timestamp, '2022-12-31 12:00', '1 day')) x
   , get_sun_times(x.generate_series, 88, 6, 0) z
WHERE z.event IN ('sunrise', 'sunset', 'solarNoon')
ORDER BY z.time;

SELECT to_timestamp(1684681741.336), degrees(azimuth), azimuth, degrees(altitude), altitude
FROM get_sun_position(to_timestamp(1684681741.336), -88.0, 6.0);

EXPLAIN ANALYZE VERBOSE
SELECT event, x.time AT TIME ZONE 'Europe/Berlin', azimuth, degrees(azimuth), altitude, degrees(altitude)
FROM get_sun_times(current_date, 51, 6, 60) x,
     get_sun_position(x.time, 51, 6) y;

EXPLAIN ANALYZE VERBOSE
SELECT *, event, x.time AT TIME ZONE 'Europe/Berlin'
FROM get_sun_times2(current_date, 51, 6, 60) x