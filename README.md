This is a pure PL/pgSQL port of [Volodymyr Agafonkin's fantastic SunCalc library](https://github.com/mourner/suncalc).

# SunCalc for PostgreSQL

**SunCalc for PostgreSQL** provides a set of functions to calculate the time of solar events like sunrise, noon and more for a specified time and location as well as the position of the sun in the sky for arbitrary times and locations.
It has been successfully tested with the official PostgreSQL Docker images from versions 9 to 15 and as such also works with other flavors of PostgreSQL like [TimescaleDB](https://github.com/timescale/timescaledb)

## Quick start

- Connect to your PostgreSQL server with your database client of choice
- Install the functions by running the contents of `suncalc/suncalc.sql`
- Check out what the two main functions do
   - Find out when you can see the sunset during your visit to the restaurant platform of Berlin's TV Tower on 25th of May 2023
       ```sql
       SELECT event, time AT TIME ZONE 'Europe/Berlin'
       FROM get_sun_times(TIMESTAMP '2023-05-25', 52.5206828, 13.409282, 239)
       WHERE event = 'sunset';
       ```
    - Find out how to position your parasol while going to the beach in the Netherlands a week after
      ```sql
      SELECT degrees(azimuth), degrees(altitude)
      FROM get_sun_position(TIMESTAMP '2023-06-01 15:23:54' AT TIME ZONE 'Europe/Amsterdam', 51.3794803,3.3887999);      
      ```

## Where to go from here?

In general the two main functions accept respectively return

- times in form of as `::timestamp with timezone`
- latitude and longitude in ±decimal degrees as `::double precision`
- height in meters as `::double precision`
- angles in radians as `::double precision` 

### Get solar events for a specific day 
`get_sun_times` calculates timestamps of all solar events for a given timestamp (positioning into a specific day), latitude, longitude, and observer's height.

- **nadir**: The lowest point of the sun during the day.
- **nightEnd**: The time when the night ends and the sky starts to lighten.
- **nauticalDawn**: The time when the sky is dark but some stars are still visible.
- **dawn**: The time when the sky starts to lighten before sunrise.
- **sunrise**: The time when the sun begins to rise above the horizon.
- **sunriseEnd**: The time when the sunrise ends.
- **goldenHourEnd**: The time when the golden hour ends.
- **solarNoon**: The highest point of the sun during the day.
- **goldenHour**: The time when the golden hour begins, characterized by warm and soft lighting.
- **sunsetStart**: The time when the sunset starts.
- **sunset**: The time when the sun is set below the horizon.
- **dusk**: The time when the sky starts to darken after sunset.
- **nauticalDusk**: The time when the sky starts to become dark after sunset.
- **night**: The time when the sky is fully dark.

### Get the sun's position in the sky

`get_sun_position`: Calculates the azimuth and altitude of the sun for a given timestamp, latitude, and longitude.
Both values are returned in **radians** and can be converted to degrees using PostgreSQL's built in `degrees()` function.

- **altitude** is the angle of the sun above the horizon with `0 <= altitude <= pi()/2` or `0° <= degrees(altitude) <= 90°`
- **azimuth** is the direction of the sun given as an offset from south with `-pi() <= azimuth <= pi()` or `-180° < degrees(azimuth) < 180°`.
    This means that a value of *0.0* is south, negative values move north via east, positive values move north via west.
    To calculate a more human-readable angle in degrees relative to north you can use `180 + degrees(azimuth)`.

## The internals

### Internal Functions

As there is no such thing as private functions in PL/pgSQL, these functions are prefixed with `sc_`.
These do the heavy lifting regarding astronomy, time and trigonometry.

- **sc_fmod**: Calculates the floating-point remainder of dividing the dividend by the divisor.
- **sc_j1970**: Returns a constant value representing the Julian date '1970-01-01 00:00:00 UTC'.
- **sc_j2000**: Returns a constant value representing the Julian date '2000-01-01 12:00:00 UTC'.
- **sc_obliquity**: Returns a constant value representing the obliquity of Earth or Earth's axial tilt.
- **sc_to_julian**: Converts an epoch timestamp to Julian date.
- **sc_from_julian**: Converts a Julian date to epoch timestamp.
- **sc_to_days**: Calculates the number of days since '2020-01-01 12:00:00 UTC'.
- **sc_right_ascension**: Calculates the right ascension for a given longitude and latitude.
- **sc_declination**: Calculates the declination for a given longitude and latitude.
- **sc_azimuth**: Calculates the azimuth for a given sideral time, latitude, and declination.
- **sc_altitude**: Calculates the altitude for a given sideral time, latitude, and declination.
- **sc_sidereal_time**: Calculates the sidereal time for a given day and longitude.
- **sc_solar_mean_anomaly**: Calculates the solar mean anomaly for a given day.
- **sc_ecliptic_longitude**: Calculates the ecliptic longitude for a given mean anomaly.
- **sc_juliancycle**: Calculates the Julian cycle for a given day and longitude.
- **sc_approximate_transit**: Calculates the approximate transit for a given hour angle, longitude, and Julian cycle.
- **sc_solar_transit_j**: Calculates the solar transit time in Julian date for a given Julian cycle, solar mean anomaly,
  and ecliptic longitude.
- **sc_hour_angle**: Calculates the hour angle for a given sideral time, latitude, and declination.
- **sc_observer_angle**: Calculates the observer angle based on the observer's height.
- **sc_get_set_j**: Returns the Julian date for the sunrise and sunset times for a given sun altitude.
- **sc_sun_coordinates**: Calculates the sun's declination and right ascension for a given day.
- **sc_time_for_horizon_angles**: Calculates the sunrise and sunset times for a given horizon angle and other
  parameters.

## Testing

The directory `test` contains scripts to generate test data and run the main functions against it.

`create_test_events.sql` creates a table named `sc_test_event` and populates it with data that has been randomly pre-recorded using `SunCalc.getTimes()` from the original *suncalc.js* library. `create_test_positions.sql` creates a table named `sc_test_position` and does the same as the aforementions script but with data from `SunCalc.getPosition()`.

`test.sql` contains two queries to run `get_sun_times` and `get_sun_position` against the pre-recorded data.
In their unmodified state they assert that the PL/pgSQL implementations approximate the original results.
And they actually do within quite narrow tolarances:
- 1 millisecond for event times
- 0.00000008 radians (~0.0000046 degrees) for altitude
- 0.000002 radians (~0.0001146 degrees) for azimuth

Feel free to optimize the functions for precision and performance!
