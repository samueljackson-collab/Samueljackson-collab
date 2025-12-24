import React from "react";
import "./photoCalendar.css";

type PhotoEntry = {
  date: string; // ISO date string (YYYY-MM-DD)
  src: string;
  alt?: string;
};

type PhotoCalendarProps = {
  title?: string;
  photos: PhotoEntry[];
};

const daysOfWeek = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];

const formatKey = (date: Date) => date.toISOString().slice(0, 10);

export default function PhotoCalendar({ title = "Photo Calendar", photos }: PhotoCalendarProps) {
  const today = new Date();
  const firstDay = new Date(today.getFullYear(), today.getMonth(), 1);
  const startWeekday = firstDay.getDay();
  const daysInMonth = new Date(today.getFullYear(), today.getMonth() + 1, 0).getDate();

  const photosByDate = photos.reduce<Record<string, PhotoEntry>>((acc, entry) => {
    acc[entry.date] = entry;
    return acc;
  }, {});

  const calendarCells = Array.from({ length: startWeekday + daysInMonth }, (_, index) => {
    const dayNumber = index - startWeekday + 1;
    if (dayNumber < 1) {
      return { key: `spacer-${index}`, day: null };
    }

    const cellDate = new Date(today.getFullYear(), today.getMonth(), dayNumber);
    const key = formatKey(cellDate);

    return {
      key,
      day: dayNumber,
      photo: photosByDate[key],
    };
  });

  return (
    <div className="photo-calendar">
      <div className="calendar-header">
        <h2 className="calendar-title">{title}</h2>
        <div className="calendar-month">
          {firstDay.toLocaleString("default", { month: "long", year: "numeric" })}
        </div>
      </div>

      <div className="calendar-grid">
        {daysOfWeek.map((weekday) => (
          <div key={weekday} className="calendar-cell calendar-weekday">
            {weekday}
          </div>
        ))}
        {calendarCells.map(({ key, day, photo }) => (
          <div key={key} className={`calendar-cell${photo ? " has-photo" : ""}`}>
            {day && <div className="calendar-date">{day}</div>}
            {photo && <img className="calendar-photo" src={photo.src} alt={photo.alt ?? ""} />}
          </div>
        ))}
      </div>
    </div>
  );
}
