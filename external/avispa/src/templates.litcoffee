
The template for the main surface.

    avispa_main = '''
        <defs>
         <marker id="Arrow"
           viewBox="0 0 10 10" refX="7" refY="5"
           markerUnits="strokeWidth"
           markerWidth="4" markerHeight="4"
           fill="#eee" stroke="#999" stroke-width="1px" stroke-dasharray="10,0"
           orient="auto">
          <path d="M 1 1 L 9 5 L 1 9 z" />
         </marker>
        </defs>
        <g class="pan">
         <g class="zoom">
          <g class="links"></g>
          <g class="nodes"></g>
          <g class="labels"></g>
         </g>
        </g>
        '''
