# Repeater Orchestra for Norns

**Repeater Orchestra** is a textural delay instrument that creates dense clouds of repeating audio. It consists of multiple tempo-synced delay lines (up to 50) with randomized timing, gain, and panning.

This project is a port of the original **Repeater Orchestra** web application by **Bryant Smith**.

## Origins & Credits

*   **Original Concept & JavaScript Implementation**: [Bryant Smith](https://codepen.io/barefootfunk)
*   **Original Web Version**: [Repeater Orchestra on CodePen](https://codepen.io/barefootfunk/pen/ZWoLmo)
*   **Original Software Demo**: [Video Demonstration by Sylvain Poitras](https://www.youtube.com/watch?v=AhKVDUIRt5I)
*   **Norns Port**: Ported with assistance from **Gemini CLI**.

## Norns Implementation

The Norns script adapts the original concept for hardware control and adds new functionality:

*   **Freeze**: Instantly lock the current audio buffer into an infinite loop, allowing you to build a texture and play over it.
*   **Dry/Wet Mix**: Blend between the direct input signal and the delay cloud (E1).
*   **Independent Monitoring**: The dry signal is monitored independently of the delay "Gate", allowing you to play over the loop even when not feeding new audio into the delays.
*   **Hardware Mapping**: Intuitive control over gains, tempo, and freeze states.

### Controls

*   **K1**: Shift modifier
*   **K2**: Toggle Gate (Mic On/Off) - When ON, audio feeds the delay lines.
*   **K3**: Toggle Freeze - Locks the current delay buffers for infinite looping.
*   **Shift + K3**: Clear all delays.

*   **E1**: Dry/Wet Mix (0% = Dry only, 100% = Wet only)
*   **E2**: Input Gain
*   **Shift + E2**: Output (Master) Gain
*   **E3**: Tempo (BPM)
*   **Shift + E3**: Number of Active Delays (1-50)

## License

MIT License. See [LICENSE](LICENSE) file for details.

---
*Porting and enhancements facilitated by Gemini CLI.*
