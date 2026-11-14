// @vitest-environment jsdom
import { afterEach, describe, expect, it } from "vitest";
import { cleanup, fireEvent, render, screen, within } from "@testing-library/react";
import App from "../App";

afterEach(cleanup);

const click = (name: string | RegExp) => fireEvent.click(screen.getAllByRole("button", { name })[0]);
const readout = () => document.querySelector(".ctl-readout")!.textContent ?? "";

describe("Digital Twin UI wiring", () => {
  it("every Next-clock press advances exactly one simulated clock edge", () => {
    render(<App />);
    expect(readout()).toContain("cycle 0");
    click("Next clock");
    expect(readout()).toContain("cycle 1");
    expect(readout()).toContain("CLEAR");
    click("Next clock");
    expect(readout()).toContain("cycle 2");
    expect(readout()).toContain("RUN");
    click("Prev clock");
    expect(readout()).toContain("cycle 1");
  });

  it("stepping through a full job reaches DONE at cycle 13 and Results shows PASS", () => {
    render(<App />);
    for (let n = 0; n < 13; n++) click("Next clock");
    expect(readout()).toContain("cycle 13");
    expect(readout()).toContain("DONE");
    click("Results");
    expect(screen.getByText(/PASS: all 16 elements match/)).toBeTruthy();
    const total = screen.getByText("Total transaction cycles").closest("tr")!;
    expect(within(total as HTMLElement).getByText("13")).toBeTruthy();
    const util = screen.getByText("Measured PE utilization (RUN)").closest("tr")!;
    expect(within(util as HTMLElement).getByText("40.0 %")).toBeTruthy();
  });

  it("Results shows no hardware output before DONE", () => {
    render(<App />);
    click("Results");
    expect(screen.getByText(/Waiting for DONE/)).toBeTruthy();
  });

  it("mesh renders 16 PEs and editing a matrix resets the run", () => {
    render(<App />);
    click("Next clock");
    click("Mesh");
    expect(document.querySelectorAll(".pe").length).toBe(16);
    click("Matrix input");
    click("A = identity");
    expect(readout()).toContain("cycle 0");
  });

  it("invalid INT8 input disables stepping and shows an error", () => {
    render(<App />);
    click("Matrix input");
    const cells = document.querySelectorAll<HTMLInputElement>("input.cell");
    fireEvent.change(cells[0], { target: { value: "300" } });
    expect(screen.getAllByText(/not a signed INT8/).length).toBeGreaterThan(0);
    expect((screen.getAllByRole("button", { name: "Next clock" })[0] as HTMLButtonElement).disabled).toBe(true);
  });

  it("negative operands flow through to the displayed result", () => {
    render(<App />);
    click("Matrix input");
    click("Mixed signs");
    click("Results");
    click("Run to DONE");
    expect(screen.getByText(/PASS: all 16 elements match/)).toBeTruthy();
  });
});
