-- This query compares the pre-recorded results from SunCalc.getTimes() with the results of the PL/pgSQL implementation.
-- The accepted tolerance is 0.001 seconds for each event.
SELECT count(*)
FROM (SELECT DISTINCT source.base_epoch,
                      source.lat,
                      source.lng,
                      source.height,
                      source_event.event_name,
                      pg_suncalc.time,
                      source_event.event_epoch,
                      abs(extract(EPOCH FROM pg_suncalc.time - source_event.event_epoch)) AS difference
      FROM sc_test_event source
               LEFT JOIN get_sun_times(source.base_epoch, source.lat, source.lng, source.height) pg_suncalc ON TRUE
               LEFT JOIN sc_test_event source_event
                         ON source.base_epoch = source_event.base_epoch AND source.lat = source_event.lat AND
                            source.lng = source_event.lng AND source.height = source_event.height AND
                            pg_suncalc.event = source_event.event_name) assert
WHERE difference > 0.001;

-- This query compares the pre-recorded results from SunCalc.getPosition() with the results of the PL/pgSQL implementation.
-- The accepted tolerances are
-- 0.00000008 radians (0.000004583662361046586°) for altitude
-- 0.000002 radians (0.00011459155902616463°) for azimuth
SELECT count(*)
FROM (SELECT source.epoch,
             source.lat,
             source.lng,
             source.azimuth,
             source.altitude,
             pg_suncalc.azimuth,
             pg_suncalc.altitude,
             abs(source.azimuth - pg_suncalc.azimuth)   AS difference_azimuth,
             abs(source.altitude - pg_suncalc.altitude) AS difference_altitude
      FROM sc_test_position source
               LEFT JOIN get_sun_position(source.epoch, source.lat, source.lng) pg_suncalc ON TRUE) assert
where difference_altitude > 0.00000008 OR difference_azimuth > 0.000002;