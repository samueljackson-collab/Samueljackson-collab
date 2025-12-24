import { useEffect, useMemo, useState } from "react";
import startOfMonth from "date-fns/startOfMonth";

// Placeholder Photo type. Replace with your actual shape as needed.
type Photo = {
  id: string;
  date: Date;
  url: string;
};

// Simulated fetch for photos based on the active month.
async function fetchPhotosForMonth(month: Date): Promise<Photo[]> {
  // In a real application, replace this with an API call that uses the month.
  const baseDate = startOfMonth(month);
  return [
    { id: "1", date: baseDate, url: "https://example.com/photo1.jpg" },
    {
      id: "2",
      date: new Date(baseDate.getFullYear(), baseDate.getMonth(), 15),
      url: "https://example.com/photo2.jpg",
    },
  ];
}

export default function PhotoCalendar() {
  const [selectedDate, setSelectedDate] = useState<Date | null>(null);
  const [activeMonth, setActiveMonth] = useState<Date>(startOfMonth(new Date()));
  const [photos, setPhotos] = useState<Photo[]>([]);
  const activeMonthLabel = useMemo(
    () => activeMonth.toLocaleDateString(undefined, { month: "long", year: "numeric" }),
    [activeMonth]
  );

  useEffect(() => {
    fetchPhotosForMonth(activeMonth).then(setPhotos);
  }, [activeMonth]);

  const handleDateClick = (date: Date) => {
    setSelectedDate(date);
  };

  const handleActiveStartDateChange = (nextActiveStartDate: Date) => {
    setActiveMonth(startOfMonth(nextActiveStartDate));
  };

  return (
    <div>
      <h2>Photo Calendar</h2>
      <p>Active month: {activeMonthLabel}</p>
      <button onClick={() => handleActiveStartDateChange(new Date(activeMonth.getFullYear(), activeMonth.getMonth() - 1, 1))}>
        Previous Month
      </button>
      <button onClick={() => handleActiveStartDateChange(new Date(activeMonth.getFullYear(), activeMonth.getMonth() + 1, 1))}>
        Next Month
      </button>
      <div>
        <p>Selected date: {selectedDate?.toDateString() ?? "None"}</p>
        <button onClick={() => handleDateClick(new Date(activeMonth.getFullYear(), activeMonth.getMonth(), 1))}>
          Select first day
        </button>
      </div>
      <ul>
        {photos.map((photo) => (
          <li key={photo.id}>
            {photo.date.toDateString()} - <a href={photo.url}>{photo.url}</a>
          </li>
        ))}
      </ul>
    </div>
  );
}
