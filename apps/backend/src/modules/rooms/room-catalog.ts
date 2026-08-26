import type { MapCatalog, RoomType } from '@campus/map';
import catalog from '@campus/map/catalog';

/** Technical room data owned exclusively by the bundled campus-map catalogue. */
export interface CatalogRoom {
  roomKey: string;
  roomNumber: string;
  buildingKey: string;
  buildingNumber: string;
  buildingNameDe: string;
  buildingNameEn: string;
  floorKey: string;
  floorNameDe: string;
  floorNameEn: string;
  roomType: RoomType;
  mapVersion: string;
  sortOrder: number;
}

const mapCatalog = catalog as MapCatalog;
const buildings = new Map(mapCatalog.buildings.map((building) => [building.buildingKey, building]));
const floors = new Map(mapCatalog.floors.map((floor) => [floor.floorKey, floor]));

const rooms: readonly CatalogRoom[] = mapCatalog.rooms
  .map((room): CatalogRoom => {
    const building = buildings.get(room.buildingKey);
    const floor = floors.get(room.floorKey);
    if (!building || !floor || !building.buildingNumber) {
      throw new Error(`Invalid campus-map catalogue relation for room "${room.roomKey}"`);
    }
    return {
      roomKey: room.roomKey,
      roomNumber: room.roomNumber,
      buildingKey: building.buildingKey,
      buildingNumber: building.buildingNumber,
      buildingNameDe: building.nameDe,
      buildingNameEn: building.nameEn,
      floorKey: floor.floorKey,
      floorNameDe: floor.nameDe,
      floorNameEn: floor.nameEn,
      roomType: room.roomType,
      mapVersion: mapCatalog.mapVersion,
      sortOrder: room.sortOrder,
    };
  })
  .sort((a, b) => a.sortOrder - b.sortOrder || a.roomKey.localeCompare(b.roomKey));

const roomsByKey = new Map(rooms.map((room) => [room.roomKey, room]));

export function catalogRoom(roomKey: string): CatalogRoom | null {
  return roomsByKey.get(roomKey) ?? null;
}
