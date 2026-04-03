# ITSI AV Example

This is a focused brief for the Audiovisual ITSI onboarding pattern captured in `work-istsi-av`.

Use it when the user wants:

- a concrete example of entity and service import in ITSI
- a repeatable service-template pattern
- guidance for building room/floor/building service hierarchies from Nagios and inventory data

## Core Pattern

The example uses a hybrid workflow:

1. import AV entities from search
2. manually create one seed service
3. manually add one generic KPI
4. create a service template from the seed service
5. define template entity rules for `equipmentBuilding`, `floorNumber`, and `roomNumber`
6. bulk import services from search
7. map a `template` column to `Service Template Link`
8. bind template rules to incoming columns in `Define Entity Rules`

That pattern is better than trying to author every ITSI object directly through raw REST.

## Data Sources

- `index=nagios sourcetype="nagios:core:serviceperf"`
- `index=nagios sourcetype="nagios:config:*"`
- `index=inventory sourcetype="inventory:av:room"`

## Entity Import Contract

Critical field mappings from the screenshots:

- `entity_name` -> `Entity Title`
- `host` -> `Entity Alias`
- `entity_description` -> `Entity Description`
- `entity_type` -> `Entity Type`
- `equipmentBuilding`, `floorNumber`, `roomNumber`, `servicegroupname` -> `Entity Information Field`

Settings:

- `Conflict Resolution`: `Update Existing Entities`
- `Conflict Resolution Field`: `entity_name`

Why this matters:

- the KPI later splits by `host`
- the template later filters entities by building/floor/room metadata

## Service Hierarchy

- room service: `equipmentBuilding + "_" + floorNumber + "_" + roomNumber`
- floor service: `equipmentBuilding + "_" + floorNumber`
- building service: `equipmentBuilding`

Dependencies:

- building -> floor
- floor -> room
- room -> none

## Template Pattern

The example template is `Generic_av_kpi`.

Entity rules on the template use placeholder matching:

- `Info equipmentBuilding matches a value to be defined in the service`
- `Info floorNumber matches a value to be defined in the service`
- `Info roomNumber matches a value to be defined in the service`

During import:

- map `template` -> `Service Template Link`
- then bind:
  - `equipmentBuilding` rule -> `equipmentBuilding` column
  - `floorNumber` rule -> `floorNumber` column
  - `roomNumber` rule -> `roomNumber` column

## Important UI Clicks

### Entity import

- `Entity Management` -> `Create Entity` -> `Import from Search`

### Seed service

- `Service and KPI management` -> `Create Service` -> `Create Service`

### Seed KPI

- open service -> `KPIs` -> `New` -> `Generic KPI`
- configure KPI with `Split by Entity = Yes`
- use `host` as the entity split field

### Template

- `Service Templates` -> `Create Service Template`

### Bulk services

- `Service and KPI management` -> `Create Service` -> `Import from Search`

## Example Room Import With Template Link

```spl
(index=nagios sourcetype=nagios:config:*) earliest=-24h sourcetype="nagios:config:host"
| eval aliasName=Host_Group
| dedup aliasName
| table aliasName Contact_Group
| join type=inner aliasName
    [ search index=inventory sourcetype="inventory:av:room" earliest=-24h
    | table aliasName equipmentBuilding floorNumber roomNumber roomStandardType]
| eval entity_name=aliasName
| eval entity_description="audiovideo"
| dedup equipmentBuilding floorNumber roomNumber
| rex field=equipmentBuilding mode=sed "s/\s+/ /g"
| eval service_title=equipmentBuilding+"_"+floorNumber+"_"+roomNumber
| eval service_Dependency=""
| eval service_description="av_floor_room_Number"
| eval service_tag="av_room_Number"
| eval template="Generic_av_kpi"
| table service_title service_Dependency service_description service_tag equipmentBuilding floorNumber roomNumber template
```

## Recommended Automation Boundary

Safe to automate:

- saved-search creation
- import search generation
- service/entity verification via REST
- object lookup and template linkage checks

Better to seed manually first:

- first KPI definition
- first service template
- threshold tuning

## Validation Checks

- entities have `host` alias
- imported services link to the template
- template entity rules are complete in the import wizard
- services attach to the expected entities
- dependency tree matches room/floor/building intent

## Related References

- `references/itsi-implementation.md`

