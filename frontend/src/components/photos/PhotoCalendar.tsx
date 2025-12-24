import React, { useCallback, useMemo } from 'react';
import Calendar from 'react-calendar';

interface Photo {
  id: string;
  url: string;
  title?: string;
}

interface DayPhotoData {
  /** ISO-8601 date string (YYYY-MM-DD) representing the day. */
  date: string;
  /** Photos associated with the date. */
  photos: Photo[];
}

interface TileContentProps {
  date: Date;
}

interface PhotoCalendarProps {
  monthData: DayPhotoData[];
  onSelectDate?: (date: Date, photos: Photo[]) => void;
}

const formatDateKey = (date: Date): string => date.toISOString().slice(0, 10);

const PhotoCalendar: React.FC<PhotoCalendarProps> = ({ monthData, onSelectDate }) => {
  const photoLookup = useMemo(() => {
    const lookup = new Map<string, Photo[]>();
    monthData.forEach((day) => {
      lookup.set(day.date, day.photos);
    });
    return lookup;
  }, [monthData]);

  const getPhotosForDate = useCallback(
    (date: Date): Photo[] => photoLookup.get(formatDateKey(date)) ?? [],
    [photoLookup],
  );

  const tileContent = useCallback(
    ({ date }: TileContentProps) => {
      const photos = getPhotosForDate(date);
      if (!photos.length) return null;

      return (
        <div className="photo-count">
          <span>{photos.length}</span>
        </div>
      );
    },
    [getPhotosForDate],
  );

  const handleClickDay = useCallback(
    (date: Date) => {
      const photos = getPhotosForDate(date);
      onSelectDate?.(date, photos);
    },
    [getPhotosForDate, onSelectDate],
  );

  return <Calendar onClickDay={handleClickDay} tileContent={tileContent} />;
};

export default PhotoCalendar;
