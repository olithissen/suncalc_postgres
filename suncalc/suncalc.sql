CREATE OR REPLACE FUNCTION sc_fmod(
    dividend double precision,
    divisor double precision
) RETURNS double precision AS
$$
BEGIN
    RETURN dividend - floor(dividend / divisor) * divisor;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

CREATE OR REPLACE FUNCTION sc_j1970() RETURNS int AS
$$
BEGIN
    RETURN 2440588;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Constant for Julian date '2020-01-01 12:00:00 UTC' --> https://en.wikipedia.org/wiki/Julian_day
CREATE OR REPLACE FUNCTION sc_j2000() RETURNS int AS
$$
BEGIN
    RETURN 2451545;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Constant for the obliquity of Earth or Earth's axial tilt --> https://en.wikipedia.org/wiki/Axial_tilt#Earth
CREATE OR REPLACE FUNCTION sc_obliquity() RETURNS double precision AS
$$
DECLARE
    obliquity_constant DOUBLE PRECISION := radians(23.4397);
BEGIN
    RETURN obliquity_constant;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Converts an epoch timestamp to Julian date
CREATE OR REPLACE FUNCTION sc_to_julian(ts double precision) RETURNS double precision AS
$$
BEGIN
    RETURN ts / 86400 - 0.5 + sc_j1970();
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Converts a Julian date to epoch timestamp
CREATE OR REPLACE FUNCTION sc_from_julian(j double precision) RETURNS double precision AS
$$
BEGIN
    RETURN (j + 0.5 - sc_j1970()) * 86400;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Calculates the number of days since '2020-01-01 12:00:00 UTC'
CREATE OR REPLACE FUNCTION sc_to_days(ts double precision) RETURNS double precision AS
$$
BEGIN
    RETURN sc_to_julian(ts) - sc_j2000();
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Calculates the right ascension for a given longitude (|) and latitude (-) --> https://en.wikipedia.org/wiki/Right_ascension
CREATE OR REPLACE FUNCTION sc_right_ascension(longitude double precision, latitude double precision) RETURNS double precision AS
$$
DECLARE
    obliquity_constant DOUBLE PRECISION := sc_obliquity();
    sin_obliquity      DOUBLE PRECISION := sin(obliquity_constant);
    cos_obliquity      DOUBLE PRECISION := cos(obliquity_constant);
BEGIN
    RETURN atan2(sin(longitude) * cos_obliquity - tan(latitude) * sin_obliquity, cos(longitude));
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Calculates the declination for a given longitude (|) and latitude (-) --> https://en.wikipedia.org/wiki/Declination
CREATE OR REPLACE FUNCTION sc_declination(longitude double precision, latitude double precision) RETURNS double precision AS
$$
DECLARE
    obliquity_constant DOUBLE PRECISION := sc_obliquity();
    sin_obliquity      DOUBLE PRECISION := sin(obliquity_constant);
    cos_obliquity      DOUBLE PRECISION := cos(obliquity_constant);
BEGIN
    RETURN asin(sin(latitude) * cos_obliquity + cos(latitude) * sin_obliquity * sin(longitude));
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Calculates the azimuth for given sideral time h, phi and declination --> https://en.wikipedia.org/wiki/Azimuth
CREATE OR REPLACE FUNCTION sc_azimuth(h double precision, phi double precision, decl double precision) RETURNS double precision AS
$$
BEGIN
    RETURN atan2(sin(h), cos(h) * sin(phi) - tan(decl) * cos(phi));
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Calculates the altitude for given sideral time h, phi and declination --> https://en.wikipedia.org/wiki/Horizontal_coordinate_system
CREATE OR REPLACE FUNCTION sc_altitude(h double precision, phi double precision, decl double precision) RETURNS double precision AS
$$
BEGIN
    RETURN asin(sin(phi) * sin(decl) + cos(phi) * cos(decl) * cos(h));
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Calculates the sidereal time for given day and longitude --> https://en.wikipedia.org/wiki/Sidereal_time
CREATE OR REPLACE FUNCTION sc_sidereal_time(day double precision, longidtude_rad double precision) RETURNS double precision AS
$$
BEGIN
    RETURN pi() / 180 * (280.16 + 360.9856235 * day) - longidtude_rad;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Calculates the solar mean anomaly for a given day --> https://en.wikipedia.org/wiki/Mean_anomaly
CREATE OR REPLACE FUNCTION sc_solar_mean_anomaly(day double precision) RETURNS double precision AS
$$
BEGIN
    RETURN pi() / 180 * (357.5291 + 0.98560028 * day);
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Calculates the ecliptic longitude for a given mean anomaly --> https://en.wikipedia.org/wiki/Ecliptic_coordinate_system#Spherical_coordinates
CREATE OR REPLACE FUNCTION sc_ecliptic_longitude(mean_anomaly double precision) RETURNS double precision AS
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

-- Calculates the julian cycle for given day and longitude
CREATE OR REPLACE FUNCTION sc_juliancycle(day double precision, longitude_rad double precision) RETURNS double precision AS
$$
BEGIN
    RETURN round(day - 0.0009 - longitude_rad / (2 * pi()));
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Calculates the approximate transit for
CREATE OR REPLACE FUNCTION sc_approximate_transit(ht double precision, lw double precision, n double precision) RETURNS double precision AS
$$
BEGIN
    RETURN 0.0009 + (ht + lw) / (2 * pi()) + n;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

CREATE OR REPLACE FUNCTION sc_solar_transit_j(ds double precision, m double precision, l double precision) RETURNS double precision AS
$$
BEGIN
    RETURN sc_j2000() + ds + 0.0053 * sin(m) - 0.0069 * sin(2 * l);
END;
$$ LANGUAGE plpgsql IMMUTABLE;

CREATE OR REPLACE FUNCTION sc_hour_angle(h double precision, phi double precision, d double precision) RETURNS double precision AS
$$
DECLARE
    result double precision;
BEGIN
    result = acos((sin(h) - sin(phi) * sin(d)) / (cos(phi) * cos(d)));
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
                            (6, 'goldenHourEnd', 'goldenHour')) times(angle, start, "end")
        LOOP
            BEGIN
                SELECT risetime, settime
                INTO rise_time, set_time
                FROM sc_time_for_horizon_angles(rec.angle, j_noon, lw, dh, phi, decl, n, m, l) AS x;
            EXCEPTION
                WHEN OTHERS THEN
                    --RAISE INFO 'No valid values for % and %. That is totally fine and just how earth works :-)', rec.start, rec."end";
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