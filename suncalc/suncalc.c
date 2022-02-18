#include "postgres.h"
#include "funcapi.h"
#include <stdio.h>
#include <math.h>
#include <time.h>
#include <string.h>
#include "fmgr.h"
#include "miscadmin.h"
#include <utils/builtins.h>

PG_MODULE_MAGIC;

#define PI 3.14159265358979323846
#define rad PI / 180.0
#define deg 180.0 / PI
#define DAY_S 86400 // Seconds per day
#define J1970 2440588
#define J2000 2451545
#define e rad * 23.4397 // obliquity of the Earth
#define J0 0.0009

#define STT_NAME_MAX 20
#define STT_ITEMS 14

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

typedef struct SolarTimeTuple
{
    char name[STT_NAME_MAX];
    long time;
} SolarTimeTuple;

typedef struct SolarTimeTuples
{
    SolarTimeTuple times[STT_ITEMS];
} SolarTimeTuples;

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
SolarTimeTuples getTimes(long date, double lat, double lng, double height);
RiseSetTime getTimeForHorizonAngles(double angle, double JNoon, double lw, double dh, double phi, double dec, double n, double M, double L);

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

SolarTimeTuples getTimes(long date, double lat, double lng, double height)
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

    SolarTimeTuples tuples;

    RiseSetTime riseSet;
    int iter;
    SolarTimeTuple *stt;

    iter = 0;

    stt = &tuples.times[iter++];
    strncpy(stt->name, "solar_noon", STT_NAME_MAX);
    stt->time = fromJulian(Jnoon);

    stt = &tuples.times[iter++];
    strncpy(stt->name, "nadir", STT_NAME_MAX);
    stt->time = fromJulian(Jnoon - 0.5);

    riseSet = getTimeForHorizonAngles(-0.833, Jnoon, lw, dh, phi, dec, n, M, L);
    stt = &tuples.times[iter++];
    strncpy(stt->name, "sunrise", STT_NAME_MAX);
    stt->time = riseSet.rise;

    stt = &tuples.times[iter++];
    strncpy(stt->name, "sunset", STT_NAME_MAX);
    stt->time = riseSet.set;

    riseSet = getTimeForHorizonAngles(-0.3, Jnoon, lw, dh, phi, dec, n, M, L);
    stt = &tuples.times[iter++];
    strncpy(stt->name, "sunrise_end", STT_NAME_MAX);
    stt->time = riseSet.rise;

    stt = &tuples.times[iter++];
    strncpy(stt->name, "sunset_start", STT_NAME_MAX);
    stt->time = riseSet.set;

    riseSet = getTimeForHorizonAngles(-6, Jnoon, lw, dh, phi, dec, n, M, L);
    stt = &tuples.times[iter++];
    strncpy(stt->name, "dawn", STT_NAME_MAX);
    stt->time = riseSet.rise;

    stt = &tuples.times[iter++];
    strncpy(stt->name, "dusk", STT_NAME_MAX);
    stt->time = riseSet.set;

    riseSet = getTimeForHorizonAngles(-12, Jnoon, lw, dh, phi, dec, n, M, L);
    stt = &tuples.times[iter++];
    strncpy(stt->name, "nautical_dawn", STT_NAME_MAX);
    stt->time = riseSet.rise;

    stt = &tuples.times[iter++];
    strncpy(stt->name, "nautical_dusk", STT_NAME_MAX);
    stt->time = riseSet.set;

    riseSet = getTimeForHorizonAngles(-18, Jnoon, lw, dh, phi, dec, n, M, L);
    stt = &tuples.times[iter++];
    strncpy(stt->name, "night_end", STT_NAME_MAX);
    stt->time = riseSet.rise;

    stt = &tuples.times[iter++];
    strncpy(stt->name, "night", STT_NAME_MAX);
    stt->time = riseSet.set;

    riseSet = getTimeForHorizonAngles(6, Jnoon, lw, dh, phi, dec, n, M, L);
    stt = &tuples.times[iter++];
    strncpy(stt->name, "golden_hour_end", STT_NAME_MAX);
    stt->time = riseSet.rise;

    stt = &tuples.times[iter++];
    strncpy(stt->name, "golden_hour", STT_NAME_MAX);
    stt->time = riseSet.set;

    return tuples;
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

PG_FUNCTION_INFO_V1(getSunPosition);

Datum getSunPosition(PG_FUNCTION_ARGS)
{
    FuncCallContext *funcctx;
    int call_cntr;
    int max_calls;
    TupleDesc tupdesc;
    AttInMetadata *attinmeta;

    float8 date;
    float8 lat;
    float8 lng;
    AzimuthAltitude az;

    /* stuff done only on the first call of the function */
    if (SRF_IS_FIRSTCALL())
    {
        MemoryContext oldcontext;

        /* create a function context for cross-call persistence */
        funcctx = SRF_FIRSTCALL_INIT();

        /* switch to memory context appropriate for multiple function calls */
        oldcontext = MemoryContextSwitchTo(funcctx->multi_call_memory_ctx);

        /* total number of tuples to be returned */
        funcctx->max_calls = 1;

        /* Build a tuple descriptor for our result type */
        if (get_call_result_type(fcinfo, NULL, &tupdesc) != TYPEFUNC_COMPOSITE)
            ereport(ERROR,
                    (errcode(ERRCODE_FEATURE_NOT_SUPPORTED),
                     errmsg("function returning record called in context "
                            "that cannot accept type record")));

        /*
         * generate attribute metadata needed later to produce tuples from raw
         * C strings
         */
        attinmeta = TupleDescGetAttInMetadata(tupdesc);
        funcctx->attinmeta = attinmeta;

        date = PG_GETARG_FLOAT8(0);
        lat = PG_GETARG_FLOAT8(1);
        lng = PG_GETARG_FLOAT8(2);
        az = getPosition(date, lat, lng);

        MemoryContextSwitchTo(oldcontext);
    }

    /* stuff done on every call of the function */
    funcctx = SRF_PERCALL_SETUP();

    call_cntr = funcctx->call_cntr;
    max_calls = funcctx->max_calls;
    attinmeta = funcctx->attinmeta;

    if (call_cntr < max_calls) /* do when there is more left to send */
    {
        char **values;
        HeapTuple tuple;
        Datum result;

        /*
         * Prepare a values array for building the returned tuple.
         * This should be an array of C strings which will
         * be processed later by the type input functions.
         */
        values = (char **)palloc(2 * sizeof(char *));
        values[0] = (char *)palloc(16 * sizeof(char));
        values[1] = (char *)palloc(16 * sizeof(char));

        snprintf(values[0], 16, "%f", az.azimuth);
        snprintf(values[1], 16, "%f", az.altitude);

        /* build a tuple */
        tuple = BuildTupleFromCStrings(attinmeta, values);

        /* make the tuple into a datum */
        result = HeapTupleGetDatum(tuple);

        /* clean up (this is not really necessary) */
        pfree(values[0]);
        pfree(values[1]);
        pfree(values);

        SRF_RETURN_NEXT(funcctx, result);
    }
    else /* do when there is no more left */
    {
        SRF_RETURN_DONE(funcctx);
    }
}

Datum getSunTimes(PG_FUNCTION_ARGS);
PG_FUNCTION_INFO_V1(getSunTimes);

Datum getSunTimes(PG_FUNCTION_ARGS)
{
    float8 date;
    float8 lat;
    float8 lng;
    float8 height;
    SolarTimeTuples tuples;
    Datum values[2];

    ReturnSetInfo *rsinfo = (ReturnSetInfo *)fcinfo->resultinfo;
    rsinfo->returnMode = SFRM_Materialize;

    MemoryContext per_query_ctx = rsinfo->econtext->ecxt_per_query_memory;
    MemoryContext oldcontext = MemoryContextSwitchTo(per_query_ctx);

    Tuplestorestate *tupstore = tuplestore_begin_heap(false, false, work_mem);
    rsinfo->setResult = tupstore;

    TupleDesc tupdesc = rsinfo->expectedDesc;
    rsinfo->setDesc = rsinfo->expectedDesc;

    uint32 times = STT_ITEMS;

    date = PG_GETARG_FLOAT8(0);
    lat = PG_GETARG_FLOAT8(1);
    lng = PG_GETARG_FLOAT8(2);
    height = PG_GETARG_FLOAT8(3);
    tuples = getTimes(date, lat, lng, height);

    while (times--)
    {
        values[0] = CStringGetTextDatum(tuples.times[times].name);
        values[1] = Int32GetDatum(tuples.times[times].time);
        bool nulls[sizeof(values)] = {0};
        tuplestore_putvalues(tupstore, tupdesc, values, nulls);
    }

    tuplestore_donestoring(tupstore);
    MemoryContextSwitchTo(oldcontext);
    PG_RETURN_NULL();
}