#include "postgres.h"
#include <stdio.h>
#include <math.h>
#include <time.h>
#include <string.h>
#include "fmgr.h"

PG_MODULE_MAGIC;

#define PI 3.14159265358979323846
#define rad PI / 180.0
#define deg 180.0 / PI
#define DAY_S 86400 // Seconds per day
#define J1970 2440588
#define J2000 2451545
#define e rad * 23.4397 // obliquity of the Earth
#define J0 0.0009

typedef struct SunCoordinates
{
    double ra;
    double dec;
} SunCoordinates;

typedef struct AzimuthAltitude
{
    double azimuth;
    double altitude;
} AzimuthAltitude;

typedef struct RiseSetTime
{
    long rise;
    long set;
} RiseSetTime;

typedef struct SolarTimes
{
    long sunrise;
    long sunset;
    long sunriseEnd;
    long sunsetStart;
    long dawn;
    long dusk;
    long nauticalDawn;
    long nauticalDusk;
    long nightEnd;
    long night;
    long goldenHour;
    long golendHourEnd;
    long solarNoon;
    long nadir;
} SolarTimes;

double toJulian(long timestamp);
long fromJulian(double j);
double toDays(long timestamp);
double rightAscension(double longitude, double latitude);
double declination(double longitude, double latitude);
double azimuth(double H, double phi, double dec);
double altitude(double H, double phi, double dec);
double siderealTime(double d, double lw);
double astroRefraction(double h);
double solarMeanAnomaly(double d);
double eclipticLongitude(double M);
double julianCycle(double d, double lw);
double approxTransit(double Ht, double lw, double n);
double solarTransitJ(double ds, double M, double L);
double hourAngle(double h, double phi, double d);
double observerAngle(double height);
double getSetJ(double h, double lw, double phi, double dec, double n, double M, double L);
SunCoordinates sunCoords(double d);
AzimuthAltitude getPosition(long date, double lat, double lng);
SolarTimes getTimes(long date, double lat, double lng, double height);
RiseSetTime getTimeForHorizonAngles(double angle, double JNoon, double lw, double dh, double phi, double dec, double n, double M, double L);

int main(int argc, char *argv[])
{
    long timestamp;
    double lat;
    double lng;

    sscanf(argv[1], "%ld", &timestamp);
    sscanf(argv[2], "%lf", &lat);
    sscanf(argv[3], "%lf", &lng);

    printf("Calculating solar ephemerides for timestamp %ld @ %f/%f\n", timestamp, lat, lng);
    printf("====================\n");

    AzimuthAltitude x = getPosition(timestamp, lat, lng);
    SolarTimes st = getTimes(timestamp, lat, lng, 80.0);

    printf("Current position:\n");
    printf("az: %lf, alt:%lf\n", deg * x.azimuth, deg * x.altitude);
    printf("====================\n");

    printf("Ephemerides:\n");
    printf("sunrise: %ld\n", st.sunrise);
    printf("sunset: %ld\n", st.sunset);
    printf("sunriseEnd: %ld\n", st.sunriseEnd);
    printf("sunsetEnd: %ld\n", st.sunsetStart);
    printf("dawn: %ld\n", st.dawn);
    printf("dusk: %ld\n", st.dusk);
    printf("nauticalDawn: %ld\n", st.nauticalDawn);
    printf("nauticalDusk: %ld\n", st.nauticalDusk);
    printf("nightEnd: %ld\n", st.nightEnd);
    printf("night: %ld\n", st.night);
    printf("goldenHour: %ld\n", st.goldenHour);
    printf("golendHourEnd: %ld\n", st.golendHourEnd);
    printf("solarNoon: %ld\n", st.solarNoon);
    printf("nadir: %ld\n", st.nadir);

    return 0;
}

double toJulian(long timestamp)
{
    return (double)timestamp / DAY_S - 0.5 + J1970;
}

long fromJulian(double j)
{
    return (j + 0.5 - J1970) * DAY_S;
}

double toDays(long timestamp)
{
    return toJulian(timestamp) - J2000;
}

double rightAscension(double longitude, double latitude)
{
    return atan2(sin(longitude) * cos(e) - tan(latitude) * sin(e), cos(longitude));
}

double declination(double longitude, double latitude)
{
    return asin(sin(latitude) * cos(e) + cos(latitude) * sin(e) * sin(longitude));
}

double azimuth(double H, double phi, double dec)
{
    return atan2(sin(H), cos(H) * sin(phi) - tan(dec) * cos(phi));
}

double altitude(double H, double phi, double dec)
{
    return asin(sin(phi) * sin(dec) + cos(phi) * cos(dec) * cos(H));
}

double siderealTime(double d, double lw)
{
    return rad * (280.16 + 360.9856235 * d) - lw;
}

double astroRefraction(double h)
{
    if (h < 0)
        // the following formula works for positive altitudes only.
        h = 0; // if h = -0.08901179 a div/0 would occur.

    // formula 16.4 of "Astronomical Algorithms" 2nd edition by Jean Meeus (Willmann-Bell, Richmond) 1998.
    // 1.02 / tan(h + 10.26 / (h + 5.10)) h in degrees, result in arc minutes -> converted to rad:
    return 0.0002967 / tan(h + 0.00312536 / (h + 0.08901179));
}

double solarMeanAnomaly(double d)
{
    return rad * (357.5291 + 0.98560028 * d);
}

double eclipticLongitude(double M)
{
    double C = rad * (1.9148 * sin(M) + 0.02 * sin(2 * M) + 0.0003 * sin(3 * M)); // equation of center
    double P = rad * 102.9372;                                                    // perihelion of the Earth

    return M + C + P + PI;
}

double julianCycle(double d, double lw)
{
    return round(d - J0 - lw / (2 * PI));
}

double approxTransit(double Ht, double lw, double n)
{
    return J0 + (Ht + lw) / (2 * PI) + n;
}
double solarTransitJ(double ds, double M, double L)
{
    return J2000 + ds + 0.0053 * sin(M) - 0.0069 * sin(2 * L);
}

double hourAngle(double h, double phi, double d)
{
    return acos((sin(h) - sin(phi) * sin(d)) / (cos(phi) * cos(d)));
}

double observerAngle(double height)
{
    return (-2.076 * sqrt(height)) / 60.0;
}

// returns set time for the given sun altitude
double getSetJ(double h, double lw, double phi, double dec, double n, double M, double L)
{
    double w = hourAngle(h, phi, dec);
    double a = approxTransit(w, lw, n);
    return solarTransitJ(a, M, L);
}

SunCoordinates sunCoords(double d)
{
    SunCoordinates s;

    double M = solarMeanAnomaly(d);
    double L = eclipticLongitude(M);

    s.dec = declination(L, 0);
    s.ra = rightAscension(L, 0);

    return s;
}

AzimuthAltitude getPosition(long date, double lat, double lng)
{
    double lw = rad * -lng;
    double phi = rad * lat;
    double d = toDays(date);
    SunCoordinates c = sunCoords(d);
    double H = siderealTime(d, lw) - c.ra;

    AzimuthAltitude position;
    position.azimuth = azimuth(H, phi, c.dec);
    position.altitude = altitude(H, phi, c.dec);

    return position;
}

SolarTimes getTimes(long date, double lat, double lng, double height)
{
    double lw = rad * -lng;
    double phi = rad * lat;
    double dh = observerAngle(height);
    double d = toDays(date);
    double n = julianCycle(d, lw);
    double ds = approxTransit(0, lw, n);
    double M = solarMeanAnomaly(ds);
    double L = eclipticLongitude(M);
    double dec = declination(L, 0);
    double Jnoon = solarTransitJ(ds, M, L);

    SolarTimes s;

    s.solarNoon = fromJulian(Jnoon);
    s.nadir = fromJulian(Jnoon - 0.5);

    RiseSetTime riseSet;

    riseSet = getTimeForHorizonAngles(-0.833, Jnoon, lw, dh, phi, dec, n, M, L);
    s.sunrise = riseSet.rise;
    s.sunset = riseSet.set;

    riseSet = getTimeForHorizonAngles(-0.3, Jnoon, lw, dh, phi, dec, n, M, L);
    s.sunriseEnd = riseSet.rise;
    s.sunsetStart = riseSet.set;

    riseSet = getTimeForHorizonAngles(-6, Jnoon, lw, dh, phi, dec, n, M, L);
    s.dawn = riseSet.rise;
    s.dusk = riseSet.set;

    riseSet = getTimeForHorizonAngles(-12, Jnoon, lw, dh, phi, dec, n, M, L);
    s.nauticalDawn = riseSet.rise;
    s.nauticalDusk = riseSet.set;

    riseSet = getTimeForHorizonAngles(-18, Jnoon, lw, dh, phi, dec, n, M, L);
    s.nightEnd = riseSet.rise;
    s.night = riseSet.set;

    riseSet = getTimeForHorizonAngles(6, Jnoon, lw, dh, phi, dec, n, M, L);
    s.golendHourEnd = riseSet.rise;
    s.goldenHour = riseSet.set;

    return s;
}

RiseSetTime getTimeForHorizonAngles(double angle, double JNoon, double lw, double dh, double phi, double dec, double n, double M, double L)
{
    double h0 = (angle + dh) * rad;

    double JSet = getSetJ(h0, lw, phi, dec, n, M, L);
    double JRise = JNoon - (JSet - JNoon);

    RiseSetTime rst;

    rst.rise = fromJulian(JRise);
    rst.set = fromJulian(JSet);

    return rst;
}

PG_FUNCTION_INFO_V1(getSunPositionAzimuth);

Datum getSunPositionAzimuth(PG_FUNCTION_ARGS)
{
    float8 date = PG_GETARG_FLOAT8(0);
    float8 lat = PG_GETARG_FLOAT8(1);
    float8 lng = PG_GETARG_FLOAT8(2);
    AzimuthAltitude az = getPosition(date, lat, lng);

    PG_RETURN_FLOAT8(az.azimuth);
}

PG_FUNCTION_INFO_V1(getSunPositionAltitude);

Datum getSunPositionAltitude(PG_FUNCTION_ARGS)
{
    float8 date = PG_GETARG_FLOAT8(0);
    float8 lat = PG_GETARG_FLOAT8(1);
    float8 lng = PG_GETARG_FLOAT8(2);
    AzimuthAltitude az = getPosition(date, lat, lng);

    PG_RETURN_FLOAT8(az.altitude);
}