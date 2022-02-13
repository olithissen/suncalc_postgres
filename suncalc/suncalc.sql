CREATE FUNCTION sun_position_azimuth(double precision, double precision, double precision) RETURNS double precision
AS
'$libdir/suncalc.so',
'getSunPositionAzimuth'
    LANGUAGE C immutable
               strict;

CREATE FUNCTION sun_position_altitude(double precision, double precision, double precision) RETURNS double precision
AS
'$libdir/suncalc.so',
'getSunPositionAltitude'
    LANGUAGE C immutable
               strict;