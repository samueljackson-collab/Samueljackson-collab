import React from "react";

export type SidebarNavItem = {
  label: string;
  href?: string;
  children?: SidebarNavItem[];
};

const INDENTATION_CLASSES: Record<number, string> = {
  0: "pl-4",
  1: "pl-8",
  2: "pl-12",
  3: "pl-16",
  4: "pl-20",
};

const FALLBACK_PADDING_STEP_REM = 1;

const getIndentationProps = (
  level: number
): { className?: string; style?: React.CSSProperties } => {
  const className = INDENTATION_CLASSES[level];

  if (className) {
    return { className };
  }

  return { style: { paddingLeft: `${(level + 1) * FALLBACK_PADDING_STEP_REM}rem` } };
};

const renderNavItems = (
  items: SidebarNavItem[],
  level = 0
): React.ReactElement[] => {
  return items.map((item) => {
    const { className: indentationClass, style } = getIndentationProps(level);
    const listItemClasses = [
      "flex items-center gap-2 py-2 text-slate-800 hover:text-slate-950",
      indentationClass,
    ]
      .filter(Boolean)
      .join(" ");

    return (
      <li key={`${item.label}-${level}`} className={listItemClasses} style={style}>
        {item.href ? (
          <a href={item.href} className="underline-offset-2 hover:underline">
            {item.label}
          </a>
        ) : (
          <span className="font-medium">{item.label}</span>
        )}
        {item.children && item.children.length > 0 && (
          <ul className="w-full space-y-1">
            {renderNavItems(item.children, level + 1)}
          </ul>
        )}
      </li>
    );
  });
};

export const SidebarNav: React.FC<{ items: SidebarNavItem[] }> = ({ items }) => {
  return (
    <nav aria-label="Sidebar navigation" className="w-full">
      <ul className="w-full space-y-1">
        {renderNavItems(items)}
      </ul>
    </nav>
  );
};

export default SidebarNav;
