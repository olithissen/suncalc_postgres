CREATE OR REPLACE FUNCTION sun_position(IN date double precision, IN lat double precision, IN lng double precision,
                                        OUT azimuth double precision, OUT altitude double precision) AS
'MODULE_PATHNAME',
'getSunPosition' LANGUAGE c IMMUTABLE
                            STRICT;

CREATE OR REPLACE FUNCTION sun_times(date double precision, lat double precision, lon double precision,
                                     height double precision)
    RETURNS TABLE
            (
                name   text,
                "time" bigint
            )
AS
'MODULE_PATHNAME',
'getSunTimes' LANGUAGE c STRICT
                         VOLATILE;