
-- Query 1
SELECT COUNT(DISTINCT v.id) FROM vol v, aviondefret adf
WHERE v.avionid = adf.id;


-- Query 2
SELECT p.id FROM pilote p, voyageur v
WHERE p.id = v.id;


-- Query 3
SELECT v.id, a_dep.nom, a_arr.nom, v.heuredépart, v.heurearrivée
FROM vol v, réservation r, aéroport a_dep, aéroport a_arr
WHERE r.volid = v.id AND a_dep.code = v.aéroportdépartcode
    AND a_arr.code = v.aéroportarrivéecode
GROUP BY v.id, a_dep.nom, a_arr.nom, v.heuredépart, v.heurearrivée
HAVING COUNT(*) >= ALL (
        SELECT COUNT(*) FROM vol v, réservation r
        WHERE r.volid = v.id
        GROUP BY v.id
    );

    -- Verifying query
    SELECT result.vol_id, MAX(voyageurs) AS voyageurs_max
    FROM (
        SELECT v.id AS vol_id, COUNT(*) AS voyageurs FROM vol v, réservation r
        WHERE r.volid = v.id
        GROUP BY v.id
        ) AS result
    GROUP BY result.vol_id
    ORDER BY voyageurs_max DESC;


-- Query 4
SELECT nom, prénom FROM utilisateur
WHERE id IN (
    SELECT p.id FROM pilote p
    WHERE NOT EXISTS (
        SELECT v.id FROM vol v, (
            SELECT a.id FROM avion a WHERE a.id NOT IN (SELECT adl.id FROM aviondeligne adl)
            ) AS autres_avions -- planes that are not passenger planes ("other planes")
        WHERE v.piloteid = p.id AND v.avionid = autres_avions.id
        )
    );


-- Query 5
    -- In total, AVG distance covered by their planes
    SELECT c.nom, AVG(v.distance)
    FROM company c, avion a, vol v
    WHERE a.compagnieid = c.id AND v.avionid = a.id
        AND c.nom IN ('ABX Air Inc','ADVANCED AIR, LLC')
    GROUP BY c.nom;

    -- Per day
    SELECT v.heuredépart::date AS depart, c.nom, AVG(v.distance)
    FROM company c, avion a, vol v
    WHERE a.compagnieid = c.id AND v.avionid = a.id
        AND c.nom IN ('ABX Air Inc','ADVANCED AIR, LLC')
    GROUP BY depart, c.nom
    ORDER BY depart;


-- Query 6
SELECT DISTINCT dep.nom AS depart, arr.nom AS destination
FROM aéroport arr, etat e1, aéroport dep, etat e2, vol v
WHERE dep.etatcode = e1.code AND arr.etatcode = e2.code
    AND dep.code = v.aéroportdépartcode AND arr.code = v.aéroportarrivéecode
    AND v.id IN (
        SELECT v1.id FROM vol v1
        WHERE v1.avionid IN (SELECT id FROM aviondeligne)
            AND EXTRACT(hour FROM v1.heuredépart::time) >= 7
            AND EXISTS (
                SELECT * FROM vol v2
                WHERE v2.aéroportdépartcode = v1.aéroportarrivéecode
                    AND v2.aéroportarrivéecode = v1.aéroportdépartcode
                    AND v2.avionid IN (SELECT id FROM aviondeligne)
                    AND EXTRACT(day FROM v2.heuredépart::date) = EXTRACT(day FROM v1.heuredépart::date)
                    AND EXTRACT(hour FROM (v2.heuredépart::time - v1.heurearrivée::time)) >= 7
            )
    );


-- Query 7
SELECT c.nom AS compagnie, AVG(vol_passagers.nombre) AS passagers_moyen
FROM company c, avion a, vol v, (
    SELECT v.id AS vol, COUNT(*) AS nombre FROM réservation r, vol v
    WHERE v.id = r.volid
    GROUP BY v.id
    HAVING COUNT(*) < 20
    ) AS vol_passagers
WHERE v.avionid = a.id AND a.compagnieid = c.id
    AND v.id = vol_passagers.vol
GROUP BY c.nom
ORDER BY passagers_moyen;


-- Query 8
SELECT DISTINCT suite_jours.id, MAX(suite_jours.jours) OVER (PARTITION BY suite_jours.id) AS max_streak
FROM (
    SELECT DISTINCT side.id, COUNT(side.separator) OVER (PARTITION BY side.id, side.separator) AS jours
    FROM (
        SELECT jours_actifs.id, jours_actifs.dates_actives,
               jours_actifs.dates_actives - CAST(ROW_NUMBER() OVER (PARTITION BY jours_actifs.id ORDER BY jours_actifs.id, jours_actifs.dates_actives) AS int) AS separator
        FROM (
            SELECT DISTINCT v.piloteid AS id, v.heuredépart::date AS dates_actives
            FROM vol v
            GROUP BY v.piloteid, dates_actives
                UNION
            SELECT DISTINCT v.piloteid, v.heurearrivée::date
            FROM vol v
            GROUP BY v.piloteid, v.heurearrivée::date
            ) AS jours_actifs -- for each pilot, select all active dates (days on which he worked)
        ) AS side -- connects consecutive days with a third column
    ) AS suite_jours -- for each pilot, give the list of streak of days he worked
ORDER BY max_streak DESC;


-- Query 9
CREATE TEMPORARY TABLE nouveaux_experts (
    status_id VARCHAR,
    start_date DATE
);

-- file must be in the /tmp directory for Postgres to have access to it
COPY nouveaux_experts
FROM '/private/tmp/csv_file.csv'
DELIMITER ',' CSV;

CREATE TABLE IF NOT EXISTS experts_status (
    status BOOL,
    expert_id VARCHAR, -- FOREIGN KEY?
    start_date DATE
);

INSERT INTO experts_status (status, expert_id, start_date)
SELECT CASE split_part(nouveaux_experts.status_id, '--', 1)
            WHEN 'existing-expert' THEN TRUE
            WHEN 'new-expert' THEN FALSE
        END,
       split_part(nouveaux_experts.status_id, '--', 2),
       nouveaux_experts.start_date
FROM nouveaux_experts;

    -- RESET TABLE
    DROP TABLE IF EXISTS experts_status;


-- Query 10
CREATE TABLE IF NOT EXISTS sujets (
    id VARCHAR PRIMARY KEY,
    sujet VARCHAR
);

INSERT INTO sujets (id, sujet)
VALUES
('MOBI','mobilité'),
('ECON','économie'),
('ECOL','écologie');

CREATE TABLE IF NOT EXISTS communication (
    code_aeroport VARCHAR,
    id_sujet VARCHAR,
    FOREIGN KEY (code_aeroport) REFERENCES aéroport(code),
    FOREIGN KEY (id_sujet) REFERENCES sujets(id)
);

INSERT INTO communication (code_aeroport, id_sujet)
VALUES
('JFK','ECON'),
('SFO','ECOL'),
('DCA','MOBI');

    -- RESET TABLE
    DROP TABLE IF EXISTS communication;
    DROP TABLE IF EXISTS sujets;
