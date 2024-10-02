-- Create database to load data into
create DATABASE CovidDeaths;

-- Load data through CSV files SQL Server Import plugin
-- Make sure the entire data was corrently loaded
select count(*) from CovidDeaths.dbo.CovidDeaths_cleaned;
select count(*) from CovidDeaths.dbo.CovidDeaths_Vaccination;

-- Preview the data
SELECT * from CovidDeaths..CovidDeaths_cleaned;
SELECT * from CovidDeaths..CovidDeaths_cleaned ORDER BY 3,4;
select * from CovidDeaths..CovidDeaths_Vaccination;

-- Pre-process data --
ALTER TABLE CovidDeaths..CovidDeaths_cleaned
ALTER COLUMN date DATE;

ALTER TABLE CovidDeaths..CovidDeaths_Vaccination
ALTER COLUMN date DATE;

SELECT * from CovidDeaths..CovidDeaths_Vaccination ORDER BY 3,4;

SELECT location, date, new_cases, total_cases, total_deaths, population
FROM CovidDeaths..CovidDeaths_cleaned
ORDER BY 1,2;

-- Exploratory data analysis
----------------------------

-- Total cases v/s Total deaths
-- Percentage probabilty of dying in a country by a specific date, if you are infected by the Covid-19 virus
SELECT location, date, total_cases, total_deaths, (CAST(total_deaths AS float)/CAST(total_cases AS FLOAT))*100 AS death_percent
FROM CovidDeaths..CovidDeaths_cleaned
ORDER BY 1,2;

--- Specific case of above: Total deaths by the end of the data --- 
-- 1.78% chance of dying(likelihood) by the latest date if infected in your country(considering the USA)
SELECT location, date, total_cases, total_deaths, (CAST(total_deaths AS float)/CAST(total_cases AS FLOAT))*100 AS death_percent
FROM CovidDeaths..CovidDeaths_cleaned
WHERE location like '%states%'
ORDER BY 1,2;

-- Total cases vs population
-- Percentage of population affected by the virus on a specific date
-- When we hit 1% case rate, to when 10% population got infected (considering the USA)
SELECT location, date, total_cases, population, (CAST(total_cases AS float)/CAST(population AS FLOAT))*100 AS case_percent
FROM CovidDeaths..CovidDeaths_cleaned
WHERE location like '%states%'
ORDER BY 1,2;

-- Highest infection rate compared to population
-- Countries where the percentage of population infected by the virus was highest
SELECT location, population, MAX(total_cases) AS highest_cases, 
MAX((CAST(total_cases AS float)/CAST(population AS FLOAT))*100) AS highest_case_percent
FROM CovidDeaths..CovidDeaths_cleaned
GROUP BY location, population
ORDER BY highest_case_percent desc;

-- Highest death count in any country
SELECT location, population, MAX(total_deaths) AS total_deaths_count
FROM CovidDeaths..CovidDeaths_cleaned
GROUP BY location, population
ORDER BY total_deaths_count desc;

-- Refine the above query to only pull contouries and not continents
SELECT location, population, MAX(total_deaths) AS total_deaths_count
FROM CovidDeaths..CovidDeaths_cleaned
WHERE continent is not null
GROUP BY location, population
ORDER BY total_deaths_count desc;

-- Highlight deaths by continents
-- Show continents with highest death counts
SELECT location, MAX(total_deaths) AS total_deaths_count
FROM CovidDeaths..CovidDeaths_cleaned
WHERE continent is null
GROUP BY location
ORDER BY total_deaths_count desc;

-- GLOBAL NUMBERS EXPLORATION

-- Everyday death percent around the world
SELECT date, SUM(new_cases) as total_cases, SUM(new_deaths) as total_deaths, -- total_deaths, (CAST(total_deaths AS float)/CAST(total_cases AS FLOAT))*100 AS death_percent
CAST(SUM(new_deaths) as float)/CAST(SUM(new_cases) as float)*100 as death_percent
FROM CovidDeaths..CovidDeaths_cleaned
where continent is not null
GROUP BY date
ORDER BY 1,2;

-- Total Deaths around the world
SELECT SUM(new_cases) as total_cases, SUM(new_deaths) as total_deaths, -- total_deaths, (CAST(total_deaths AS float)/CAST(total_cases AS FLOAT))*100 AS death_percent
CAST(SUM(new_deaths) as float)/CAST(SUM(new_cases) as float)*100 as death_percent
FROM CovidDeaths..CovidDeaths_cleaned
where continent is not null
ORDER BY 1,2;

--- Now view the vaccination data
SELECT * FROM CovidDeaths..CovidDeaths_cleaned deaths
JOIN CovidDeaths..CovidDeaths_Vaccination vaccinations
ON deaths.location = vaccinations.location
and deaths.date = vaccinations.date;

-- Check how many people got vaccianted in each country on a spcific date
-- Partial
SELECT deaths.continent, deaths.location, deaths.date, deaths.population,
vaccinations.new_vaccinations
 FROM CovidDeaths..CovidDeaths_cleaned deaths
JOIN CovidDeaths..CovidDeaths_Vaccination vaccinations
ON deaths.location = vaccinations.location
and deaths.date = vaccinations.date
where deaths.continent is not null
order by 2,3

-- Rolling count of toal vaccinations given in each country
SELECT deaths.continent, deaths.location, deaths.date, deaths.population,
vaccinations.new_vaccinations,
SUM(vaccinations.new_vaccinations) OVER(PARTITION BY deaths.location ORDER BY deaths.date) as rolling_vaccinations
FROM CovidDeaths..CovidDeaths_cleaned deaths
JOIN CovidDeaths..CovidDeaths_Vaccination vaccinations
ON deaths.location = vaccinations.location
and deaths.date = vaccinations.date
where deaths.continent is not null
order by 2,3

-- Now we want to see the % of people vaccinated by the population of a location(country)
-- Use of cte, check the last entry in the window of the partition to know the final percentage
with vaccination_rate (
    continent, location, date,population, new_vaccinations, rolling_vaccinations
) as 
(
    SELECT deaths.continent, deaths.location, deaths.date, deaths.population,
    vaccinations.new_vaccinations,
    SUM(vaccinations.new_vaccinations) OVER(PARTITION BY deaths.location ORDER BY deaths.date) as rolling_vaccinations
    FROM CovidDeaths..CovidDeaths_cleaned deaths
    JOIN CovidDeaths..CovidDeaths_Vaccination vaccinations
    ON deaths.location = vaccinations.location
    and deaths.date = vaccinations.date
    where deaths.continent is not null
-- order by 2,3
)
SELECT *, CAST(rolling_vaccinations as float)/CAST(population as float)*100 
as vaccinate_percent from vaccination_rate;

-- Use temp table to store some results in a temp table before calculating percentage

DROP table if exists #percent_population_vaccinated
CREATE TABLE #percent_population_vaccinated
(
    continent nvarchar(255),
    location nvarchar(255),
    date DATE,
    population bigint,
    new_vaccinations bigint,
    rolling_vaccinations bigint,
)
INSERT INTO #percent_population_vaccinated
SELECT deaths.continent, deaths.location, deaths.date, deaths.population,
vaccinations.new_vaccinations,
SUM(vaccinations.new_vaccinations) OVER(PARTITION BY deaths.location ORDER BY deaths.date) as rolling_vaccinations
FROM CovidDeaths..CovidDeaths_cleaned deaths
JOIN CovidDeaths..CovidDeaths_Vaccination vaccinations
ON deaths.location = vaccinations.location
and deaths.date = vaccinations.date
where deaths.continent is not null

SELECT *, CAST(rolling_vaccinations as float)/CAST(population as float)*100 
as vaccinate_percent from #percent_population_vaccinated;

-- Create view for using the resultant data later 
CREATE VIEW view_percent_population as
SELECT SUM(new_cases) as total_cases, SUM(new_deaths) as total_deaths,
CAST(SUM(new_deaths) as float)/CAST(SUM(new_cases) as float)*100 as death_percent
FROM CovidDeaths..CovidDeaths_cleaned
where continent is not null;