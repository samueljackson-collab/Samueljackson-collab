import React, { ReactNode } from "react";

export type LargeButtonProps = {
  label: string;
  onClick?: () => void;
  disabled?: boolean;
  type?: "button" | "submit" | "reset";
  icon?: ReactNode;
  className?: string;
};

/**
 * Large CTA-style button with high-contrast primary styling for elderly mode.
 * Primary colors use darker blues (bg-blue-800/border-blue-900) to ensure
 * a >=4.5:1 contrast ratio against white backgrounds while maintaining
 * accessible hover and focus-visible states.
 */
export function LargeButton({
  label,
  onClick,
  disabled = false,
  type = "button",
  icon,
  className = "",
}: LargeButtonProps) {
  const baseStyles =
    "inline-flex items-center justify-center w-full gap-2 rounded-xl border px-6 py-4 text-lg font-semibold transition-colors focus:outline-none";
  const interactiveStyles =
    "bg-blue-800 border-blue-900 text-white hover:bg-blue-900 hover:border-blue-950 focus-visible:ring-4 focus-visible:ring-blue-300 focus-visible:ring-offset-2 focus-visible:ring-offset-white";
  const disabledStyles = "disabled:opacity-60 disabled:cursor-not-allowed";

  return (
    <button
      type={type}
      onClick={onClick}
      disabled={disabled}
      className={`${baseStyles} ${interactiveStyles} ${disabledStyles} ${className}`.trim()}
      aria-disabled={disabled}
    >
      {icon}
      <span>{label}</span>
    </button>
  );
}

export default LargeButton;
