DROP FUNCTION IF EXISTS j1970;
DROP FUNCTION IF EXISTS j2000;
DROP FUNCTION IF EXISTS obliquity;
--drop function if exists tojulian;
DROP FUNCTION IF EXISTS fromjulian;
DROP FUNCTION IF EXISTS todays;
DROP FUNCTION IF EXISTS rightascension;
DROP FUNCTION IF EXISTS declination;
DROP FUNCTION IF EXISTS azimuth;
DROP FUNCTION IF EXISTS altitude;
DROP FUNCTION IF EXISTS siderealtime;
DROP FUNCTION IF EXISTS solarmeananomaly;
DROP FUNCTION IF EXISTS eclipticlongitude;
DROP FUNCTION IF EXISTS juliancycle;
DROP FUNCTION IF EXISTS approxtransit;
DROP FUNCTION IF EXISTS solartransitj;
DROP FUNCTION IF EXISTS hourangle;
DROP FUNCTION IF EXISTS observerangle;
DROP FUNCTION IF EXISTS gettimeforhorizonangles;
DROP FUNCTION IF EXISTS getsuntimes;

CREATE OR REPLACE FUNCTION j1970() RETURNS int AS
$$
BEGIN
    RETURN 2440588;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION j2000() RETURNS int AS
$$
BEGIN
    RETURN 2451545;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION obliquity() RETURNS double precision AS
$$
BEGIN
    RETURN radians(23.4397);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION tojulian(ts double precision) RETURNS double precision AS
$$
BEGIN
    RETURN ts / 86400 - 0.5 + j1970();
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION fromjulian(j double precision) RETURNS double precision AS
$$
BEGIN
    RETURN (j + 0.5 - j1970()) * 86400;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION todays(ts double precision) RETURNS double precision AS
$$
BEGIN
    RETURN tojulian(ts) - j2000();
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION rightascension(longitude double precision, latitude double precision) RETURNS double precision AS
$$
BEGIN
    RETURN atan2(sin(longitude) * cos(obliquity()) - tan(latitude) * sin(obliquity()), cos(longitude));
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION declination(longitude double precision, latitude double precision) RETURNS double precision AS
$$
BEGIN
    RETURN asin(sin(latitude) * cos(obliquity()) + cos(latitude) * sin(obliquity()) * sin(longitude));
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION azimuth(h double precision, phi double precision, decl double precision) RETURNS double precision AS
$$
BEGIN
    RETURN atan2(sin(h), cos(h) * sin(phi) - tan(decl) * cos(phi));
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION altitude(h double precision, phi double precision, decl double precision) RETURNS double precision AS
$$
BEGIN
    RETURN asin(sin(phi) * sin(decl) + cos(phi) * cos(decl) * cos(h));
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION siderealtime(d double precision, lw double precision) RETURNS double precision AS
$$
BEGIN
    RETURN pi() / 180 * (280.16 + 360.9856235 * d) - lw;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION solarmeananomaly(d double precision) RETURNS double precision AS
$$
BEGIN
    RETURN pi() / 180 * (357.5291 + 0.98560028 * d);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION eclipticlongitude(m double precision) RETURNS double precision AS
$$
DECLARE
    c double precision;
    p double precision;
BEGIN
    c = pi() / 180 * (1.9148 * sin(m) + 0.02 * sin(2 * m) + 0.0003 * sin(3 * m)); -- equation of center
    p = pi() / 180 * 102.9372; -- perihelion of the Earth

    RETURN m + c + p + pi();
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION juliancycle(d double precision, lw double precision) RETURNS double precision AS
$$
BEGIN
    RETURN round(d - 0.0009 - lw / (2 * pi()));
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION approxtransit(ht double precision, lw double precision, n double precision) RETURNS double precision AS
$$
BEGIN
    RETURN 0.0009 + (ht + lw) / (2 * pi()) + n;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION solartransitj(ds double precision, m double precision, l double precision) RETURNS double precision AS
$$
BEGIN
    RETURN j2000() + ds + 0.0053 * sin(m) - 0.0069 * sin(2 * l);
END;
$$ LANGUAGE plpgsql;

----------------------------------------------------------------------

CREATE OR REPLACE FUNCTION hourangle(h double precision, phi double precision, d double precision) RETURNS double precision AS
$$
DECLARE
    result double precision;
BEGIN
    RAISE INFO 'h % phi % d %', h, phi, d;

    result = sin(h);
    RAISE INFO 'sin(h) %', result;

    result = sin(phi);
    RAISE INFO 'sin(phi) %', result;

    result = sin(d);
    RAISE INFO 'sin(d) %', result;

    result = cos(phi);
    RAISE INFO 'cos(phi) %', result;

    result = cos(d);
    RAISE INFO 'cos(d) %', result;

    result = (sin(h) - sin(phi) * sin(d)) / (cos(phi) * cos(d));
    RAISE INFO 'result %', result;

    result = acos((sin(h) - sin(phi) * sin(d)) / (cos(phi) * cos(d)));
    RAISE INFO 'result %', result;
    RETURN result;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION observerangle(height double precision) RETURNS double precision AS
$$
BEGIN
    RETURN (-2.076 * sqrt(height)) / 60.0;
END;
$$ LANGUAGE plpgsql;

-- returns set time for the given sun altitude
CREATE OR REPLACE FUNCTION getsetj(h double precision,
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
    w = hourangle(h, phi, decl);
    a = approxtransit(w, lw, n);
    RETURN solartransitj(a, m, l);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION suncoords(d double precision,
                                     OUT decl double precision,
                                     OUT ra double precision) RETURNS record AS
$$
DECLARE
    m double precision;
    l double precision;
BEGIN
    m = solarmeananomaly(d);
    l = eclipticlongitude(m);

    decl = declination(l, 0);
    ra = rightascension(l, 0);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION getsunposition(ts timestamp WITH TIME ZONE,
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
    d = todays(date);

    SELECT * INTO decl, ra FROM suncoords(d);
    h = siderealtime(d, lw) - ra;

    azimuth = azimuth(h, phi, decl);
    altitude = altitude(h, phi, decl);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION gettimeforhorizonangles(angle double precision,
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
    jset = getsetj(h0, lw, phi, decl, n, m, l);
    RAISE INFO '%', jset;
    jrise = jnoon - (jset - jnoon);

    risetime = fromjulian(jrise);
    settime = fromjulian(jset);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION getsuntimes(ts timestamp WITH TIME ZONE,
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
    date     double precision;
    lw       double precision;
    phi      double precision;
    dh       double precision;
    d        double precision;
    n        double precision;
    ds       double precision;
    m        double precision;
    l        double precision;
    decl     double precision;
    jnoon    double precision;
    rec      RECORD;
    risetime double precision;
    settime  double precision;
BEGIN
    date = extract('epoch' FROM ts)::double precision;

    lw = pi() / 180 * -lng;
    phi = pi() / 180 * lat;
    dh = observerangle(height);
    d = todays(date);
    n = juliancycle(d, lw);
    ds = approxtransit(0, lw, n);
    m = solarmeananomaly(ds);
    l = eclipticlongitude(m);
    decl = declination(l, 0);
    jnoon = solartransitj(ds, m, l);

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
    time := to_timestamp(fromjulian(jnoon)) AT TIME ZONE 'UTC';
    SELECT * INTO az, alt FROM getsunposition(time, lat, lng);
    RETURN NEXT;

    event := 'nadir';
    time := to_timestamp(fromjulian(jnoon - 0.5)) AT TIME ZONE 'UTC';
    SELECT * INTO az, alt FROM getsunposition(time, lat, lng);
    RETURN NEXT;

    FOR rec IN SELECT angle, start, "end" FROM temp_solartimes
        LOOP
            SELECT *
            INTO risetime, settime
            FROM gettimeforhorizonangles(rec.angle, jnoon, lw, dh, phi, decl, n, m, l) AS x;

            event := rec.start;
            time := to_timestamp(risetime) AT TIME ZONE 'UTC';
            SELECT * INTO az, alt FROM getsunposition(time, lat, lng);

            RETURN NEXT;

            event := rec."end";
            time := to_timestamp(settime) AT TIME ZONE 'UTC';
            SELECT * INTO az, alt FROM getsunposition(time, lat, lng);
            RETURN NEXT;
        END LOOP;

    DROP TABLE temp_solartimes;
END ;
$$ LANGUAGE plpgsql;

--

SELECT todays(extract('epoch' FROM now())::bigint);

SELECT rightascension(51.0, 6.0);
SELECT declination(51.0, 6.0);

SELECT *
FROM suncoords(1.0);

SELECT degrees(azimuth), degrees(altitude), azimuth, altitude
FROM getsunposition('2013-03-05 00:00:00 UTC', 50.5, 30.5);

SELECT degrees(azimuth), degrees(altitude), azimuth, altitude
FROM getsunposition(now(), 51, 6);


SELECT event, "time" AT TIME ZONE 'Europe/Berlin'
FROM getsuntimes('2013-03-05 00:00:00 UTC', 50.5, 30.5, 0.0);

SELECT event, time AT TIME ZONE 'Europe/Berlin' "time", degrees(az) "azimuth", degrees(alt) "altitude"
FROM getsuntimes('2022-05-27 00:00:00 CEST', 51, 6, 0.0)
ORDER BY time;