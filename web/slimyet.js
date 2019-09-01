/* -*- fill-column: 80; js-indent-level: 2; -*- */
/*jshint sub:true,loopfunc:true */
/*
 * Copyright © 2012 Mozilla Corporation
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this file,
 * You can obtain one at http://mozilla.org/MPL/2.0/.
 */

"use strict";

// Vars from query or hash in form #key[:val],...
var gQueryVars = (function () {
  var ret = {};
  function expand(target, outer, inner) {
    var vars = target.split(outer);
    for (var x in vars) {
      x = vars[x].split(inner);
      ret[decodeURIComponent(x[0]).toLowerCase()] = x.length > 1 ? decodeURIComponent(x[1]) : true;
    }
  }
  if (document.location.search)
    expand(document.location.search.slice(1), '&', '=');
  if (document.location.hash)
    expand(document.location.hash.slice(1), ',', ':');
  return ret;
})();

// Width in pixels of highlight (zoom) selector
var gHighlightWidth = gQueryVars['zoomwidth'] ? +gQueryVars['zoomwidth'] : 400;

// Offset between tooltip and cursor
var gTooltipOffset = 'tooltipoffset' in gQueryVars ? +gQueryVars['tooltipoffset'] : 10;

// Coalesce datapoints to keep them under this many per zoom level.
// Default to 150, or 0 (disabled) if nocondense is supplied
var gMaxPoints = gQueryVars['maxpoints'] ? +gQueryVars['maxpoints'] : (gQueryVars['nocondense'] ? 0 : 150);

// 10-class paired qualitative color scheme from http://colorbrewer2.org/.
// Ordered so that the important memory lines are given more prominent colors.
var gDefaultColors = [
  "#A6CEE3", /* light blue */
  "#B2DF8A", /* light green */
  "#FB9A99", /* light red */
  "#FDBF6F", /* light orange */
  "#33A02C", /* dark green */
  "#1F78B4", /* dark blue */
  "#E31A1C", /* dark red */
  "#6A3D9A", /* dark purple */
  "#FF7F00", /* dark orange */
  "#CAB2D6", /* light purple */
];

var gDarkColorsFirst = [
  "#1F78B4", /* dark blue */
  "#33A02C", /* dark green */
  "#E31A1C", /* dark red */
  "#6A3D9A", /* dark purple */
  "#FF7F00", /* dark orange */
  "#A6CEE3", /* light blue */
  "#B2DF8A", /* light green */
  "#FB9A99", /* light red */
  "#CAB2D6", /* light purple */
  "#FDBF6F", /* light orange */
];

// Contents of data.json
var gData;

// Key data lookup
var gCommits = {};
var gTests = {};

// Current test
var gDefaultTestID = 'program-hello-binarysize';
var gCurrentTestID = gDefaultTestID;
var gPinnedTestIDs = {};

// Our plot
var gPlot;

// Range of all non-null datapoints.
var gDataRange;

// ObjectURLs that have been allocated and need to be cleared.
var gObjectURLs = [];

//
// Utility
//

// Shorthand for $(document.createElement(<e>))[.attr(<attrs>)[.css(<css>)]]
jQuery.new = function(e, attrs, css) {
  var ret = jQuery(document.createElement(e));
  if (attrs) ret.attr(attrs);
  if (css) ret.css(css);
  return ret;
};

// Log message/error to console if available
function logMsg(obj) {
  if (window.console && window.console.log) {
    window.console.log(obj);
  }
}

function logError(obj) {
  if (window.console) {
    if (window.console.error)
      window.console.error(obj);
    else if (window.console.log)
      window.console.log("ERROR: " + obj);
  }
}

function prettyDate(aTimestamp) {
  return new Date(aTimestamp * 1000).toISOString().replace("T", " ").replace(".000Z", "");
}

function mkDelta(mem, lastmem, unit) {
  var delta = mem - lastmem;
  var obj = $.new('span').addClass('delta');
  if (delta < 0) {
    obj.text('Δ -'+formatUnit(-delta, unit));
    obj.addClass('neg');
  } else if (delta == 0) {
    obj.text('Δ '+formatUnit(delta, unit));
    obj.addClass('equ');
  } else {
    obj.text('Δ '+formatUnit(delta, unit));
    obj.addClass('pos');
  }
  if (Math.abs(delta) / mem > 0.02)
    obj.addClass('significant');
  return obj;
}

function gitURL(rev) {
  var commit = gCommits[rev];
  var firstLine = commit.message.split('\n')[0];
  var i = firstLine.indexOf(': ');
  var repo = firstLine.substr(0, i);
  var message = firstLine.substr(i+2);
  var m = message.match(/^Merge pull request #(\d+) from /);
  var href;
  if (m)
    return 'https://github.com/D-Programming-Language/'+repo+'/pull/'+m[1];
  else
    return 'https://bitbucket.org/cybershadow/d/commits/' + rev;
}

function gitRangeURL(rev0, rev1) {
  // Convert closed range to half-open range
  if (gCommits[rev0].prev)
    rev0 = gCommits[rev0].prev.commit;
  return 'https://bitbucket.org/cybershadow/d/branches/compare/'+rev1+'..'+rev0+'#commits';
}

function mkGitLink(rev) {
  return $.new('a', { 'class': 'buildlink', 'target': '_blank' })
          .attr('href', gitURL(rev))
          .text(rev.slice(0,12));
}

// float 12039123.439 -> String "12,039,123.44"
// (commas and round %.02)
function prettyFloat(aFloat) {
  var ret = Math.round(aFloat * 100).toString();
  if (ret == "0") return ret;
  if (ret.length < 3)
    ret = (ret.length < 2 ? "00" : "0") + ret;

  var clen = (ret.length - 2) % 3;
  ret = ret.slice(0, clen) + ret.slice(clen, -2).replace(/[0-9]{3}/g, ',$&') + '.' + ret.slice(-2);
  return clen ? ret : ret.slice(1);
}

// Takes a int number of bytes, converts to appropriate units (B/KiB/MiB/GiB),
// returns a prettyFloat()'d string
// formatBytes(923044592344234) -> "859,652.27GiB"
function formatBytes(raw, ref) {
  if (ref === undefined) ref=raw;
  if (ref / 1024 < 2) {
    return prettyFloat(raw) + "B";
  } else if (ref / Math.pow(1024, 2) < 2) {
    return prettyFloat(raw / 1024) + "KiB";
  } else if (ref / Math.pow(1024, 3) < 2) {
    return prettyFloat(raw / Math.pow(1024, 2)) + "MiB";
  } else {
    return prettyFloat(raw / Math.pow(1024, 3)) + "GiB";
  }
}

// Takes a int number of nanoseconds, converts to appropriate units (ns/μs/ms/s),
// returns a prettyFloat()'d string
function formatTime(raw, ref) {
  if (ref === undefined) ref=raw;
  if (ref / 1000 < 2) {
    return prettyFloat(raw) + "ns";
  } else if (ref / Math.pow(1000, 2) < 2) {
    return prettyFloat(raw / 1000) + "μs";
  } else if (ref / Math.pow(1000, 3) < 2) {
    return prettyFloat(raw / Math.pow(1000, 2)) + "ms";
  } else {
    return prettyFloat(raw / Math.pow(1000, 3)) + "s";
  }
}

// As above, but with an unspecified amount of things. (e.g. instructions)
function formatAmount(raw, ref) {
  if (ref === undefined) ref=raw;
  if (ref / 1000 < 2) {
    return prettyFloat(raw);
  } else if (ref / Math.pow(1000, 2) < 2) {
    return prettyFloat(raw / 1000) + "K";
  } else if (ref / Math.pow(1000, 3) < 2) {
    return prettyFloat(raw / Math.pow(1000, 2)) + "M";
  } else {
    return prettyFloat(raw / Math.pow(1000, 3)) + "B";
  }
}

function formatUnit(raw, unit, ref) {
  if (unit=='bytes')
    return formatBytes(raw, ref);
  if (unit=='nanoseconds')
    return formatTime(raw, ref);
  return formatAmount(raw, ref);
}

// Pass to progress on $.ajax to show the progress div for this request
function dlProgress() {
  var xhr = $.ajaxSettings.xhr();
  var url;
  if (xhr) {
    xhr._open = xhr.open;
    xhr.open = function() {
      if (arguments.length >= 2)
        url = arguments[1];
      return this._open.apply(this, arguments);
    };
    xhr.addEventListener("progress", function(e) {
      // We can't use e.total because it is bogus for gzip'd data: Firefox sets
      // loaded to the decompressed data but total to compressed, and chromium
      // doesn't set total.
      if (e.loaded) {
        if (e.loaded == e.total) {
          $('#dlProgress').empty();
        } else {
          $('#dlProgress').text("Downloading " + url + " - " +
                                formatBytes(e.loaded));
        }
      }
    }, false);
  }
  return xhr;
}

//
// Tooltip
//

// A tooltip that can be positioned relative to its parent via .hover()
function Tooltip(parent) {
  if (!(this instanceof Tooltip)) {
    logError("Tooltip() used incorrectly");
    return;
  }
  this.obj = $.new('div', { 'class' : 'tooltip' }, { 'display' : 'none' });
  this.content = $.new('div', { 'class' : 'content' }).appendTo(this.obj);
  if (parent)
    this.obj.appendTo(parent);

  // Track mouseover state for delayed fade out
  var self = this;
  this.mouseover = false;
  this.obj.bind("mouseover", function(e) {
    self.mouseover = true;
    self._fadeIn();
  });
  this.obj.mouseleave(function(e) {
    self.mouseover = false;
    if (self.obj.is(":visible") && !self.hovered) {
      self._fadeOut();
    }
  });

  this.obj.data('owner', this);
  this.hovered = false;
  this.faded = true;
}

Tooltip.prototype.append = function(obj) {
  this.content.append(obj);
};

Tooltip.prototype.empty = function() {
  this.content.empty();
  this.seriesname = null;
  this.buildset = null;
  this.buildindex = null;
};

Tooltip.prototype.hover = function(x, y, nofade) {
  this.hovered = true;
  var poffset = this.obj.parent().offset();

  var h = this.obj.outerHeight();
  var w = this.obj.outerWidth();
  // Lower-right of cursor
  var top = y + gTooltipOffset;
  var left = x + gTooltipOffset;
  // Move above cursor if too far down
  if (window.innerHeight + window.scrollY < poffset.top + top + h + 30)
    top = y - h - gTooltipOffset;
  // Move left of cursor if too far right
  if (window.innerWidth + window.scrollX < poffset.left + left + w + 30)
    left = x - w - gTooltipOffset;

  this.obj.css({
    top: top,
    left: left
  });

  // Show tooltip
  if (!nofade)
    this._fadeIn();
};

Tooltip.prototype.unHover = function() {
  this.hovered = false;
  if (!this.mouseover) {
    // Don't actually fade till the mouse goes away, see handlers in constructor
    this._fadeOut();
  }
};

Tooltip.prototype._fadeIn = function() {
  if (this.faded) {
    this.obj.stop().fadeTo(200, 1);
    this.faded = false;
  }
};

Tooltip.prototype._fadeOut = function() {
  this.faded = true;
  this.obj.stop().fadeTo(200, 0, function () { $(this).hide(); });
};

// value      - Value of displayed point
// label      - tooltip header/label
// buildset   - set of builds shown for this graph (different from gBuildInfo as
//              it may have been condensed)
// buildindex - index of this build in buildset
// series     - the series we are showing
Tooltip.prototype.showBuild = function(label, series, buildset, buildindex, seriesname, seriesindex) {
  this.empty();
  this.build_series = series;
  this.build_seriesname = seriesname;
  this.build_set = buildset;
  this.build_index = buildindex;

  var value = series[buildindex][1];
  var build = buildset[buildindex];
  var rev = build['firstrev'];
  var unit = gTests[seriesname].unit;

  // Label
  //this.append($.new('h3').text(label));
  // Build link / time
  var ttinner = $.new('p');
  if (getCurrentTestIDs().length > 1)
    ttinner.append($.new('span').css('color', gDarkColorsFirst[seriesindex]).text(gTests[seriesname].name), ': ');
  var valobj = $.new('p').text(formatUnit(value, unit) + ' ').attr('title', value + ' ' + unit);
  // Delta
  var prev = gCommits[rev].prev;
  if (prev && seriesname in prev.results) {
    var prevResult = prev.results[seriesname];
    if (prevResult.error === null)
      valobj.append(mkDelta(value, prevResult.value, unit));
  }
  ttinner.append(valobj);
  if (!build['lastrev']) {
    ttinner.append($.new('b').text('commit '));
    ttinner.append(mkGitLink(rev));
    ttinner.append($.new('p').addClass('timestamp').text(prettyDate(build['timerange'][0])));
    ttinner.append($.new('p').addClass('commit-message').text(gCommits[rev].message));
  } else {
    // Multiple revisions, add range link
    ttinner.append($.new('b').text(build['numrevs'] + ' commits'));
    ttinner.append(":");
    ttinner.append($.new('p')
                   .append(mkGitLink(rev))
                   .append(" (")
                   .append(prettyDate(build['timerange'][0]))
                   .append(")"));
    ttinner.append($.new('hr').css('border-top', '2px dotted #888'));
    ttinner.append($.new('p')
                   .append(mkGitLink(build['lastrev']))
                   .append(" (")
                   .append(prettyDate(build['timerange'][1]))
                   .append(")"));
  }

  // Clearly announce gaps in data
  {
    // Find the tested commit in this commit group
    var rev1 = build['lastrev'] ? build['lastrev'] : rev;
    var testedCommit = null;
    for (var c = gCommits[rev]; c.prev.commit != rev1; c = c.next)
      if (seriesname in c.results) {
        testedCommit = c;
        break;
      }

    // Backtrack to the previous tested commit
    var numSkipped = 0;
    if (testedCommit) {
      c = testedCommit.prev;
      while (c && !(seriesname in c.results)) {
        c = c.prev;
        numSkipped++;
      }
    }

    if (numSkipped > 0 || (c && c.error) || (c && c.results[seriesname].error !== null))
      ttinner.append(
        $.new('hr')
          .css('border-top', '1px solid #888'),
        $.new('p')
          .text((numSkipped > 0 ?
				 numSkipped +
                 ' untested commit' + (numSkipped > 1 ? 's' : '') +
                 ' since ' :
				 'Previous commit, '
				) +
                (c === null
                 ? 'the beginning'
                 : (c.commit.slice(0,12) +
                    ' (' + prettyDate(c.time) + ')' +
                    (c.error ? ', which failed to build,' :
					 c.results[seriesname].error !== null ? ', which errored,' : '')
                   )) +
                ' not shown'));
  }

  this.append(ttinner);
};

//
// Plot functions
//

// X-axis tick logic table.
// threshold: first item with threshold < current view range is used
// init: adjusts d to a point from where to start creating ticks (generally rounds down to some round date);
//       also applied for all successive items (to zero out the lower denominations too).
// next: move d to where the next tick should be drawn.
var gDateAxisThresholds = [
  { threshold :1080*24*60*60, init : function(d) { d.setMonth       (0); }, next : function(d) { d.setFullYear(d.getFullYear()+ 1); }},
  { threshold : 640*24*60*60, init : function(d) { d.setMonth       (0); }, next : function(d) { d.setMonth   (d.getMonth   ()+ 6); }},
  { threshold :  60*24*60*60, init : function(d) { d.setDate        (1); }, next : function(d) { d.setMonth   (d.getMonth   ()+ 1); }},
  { threshold :  15*24*60*60, init : function(d) { d.setDate        (1); }, next : function(d) { d.setDate    (d.getDate    ()+12); d.setDate(Math.max(1, ((d.getDate()-1)/10|0)*10)); }},
  { threshold :   2*24*60*60, init : function(d) { d.setHours       (0); }, next : function(d) { d.setDate    (d.getDate    ()+ 1); }},
  { threshold :     24*60*60, init : function(d) { d.setHours       (0); }, next : function(d) { d.setHours   (d.getHours   ()+12); }},
  { threshold :      2*60*60, init : function(d) { d.setMinutes     (0); }, next : function(d) { d.setHours   (d.getHours   ()+ 1); }},
  { threshold :      1*60*60, init : function(d) { d.setMinutes     (0); }, next : function(d) { d.setMinutes (d.getMinutes ()+30); }},
  { threshold :        20*60, init : function(d) { d.setMinutes     (0); }, next : function(d) { d.setMinutes (d.getMinutes ()+10); }},
  { threshold :         2*60, init : function(d) { d.setSeconds     (0); }, next : function(d) { d.setMinutes (d.getMinutes ()+ 1); }},
  { threshold :           30, init : function(d) { d.setSeconds     (0); }, next : function(d) { d.setSeconds (d.getSeconds ()+10); }},
  { threshold :           10, init : function(d) { d.setSeconds     (0); }, next : function(d) { d.setSeconds (d.getSeconds ()+ 5); }},
  { threshold :            1, init : function(d) { d.setMilliseconds(0); }, next : function(d) { d.setSeconds (d.getSeconds ()+ 1); }},
];

if (false) { // Zoom debugging
  $(document).on('keydown', function(e) {
    if (e.shiftKey || e.ctllKey || e.altKey || e.metaKey) return;
    var left = Number(gPlot.zoomRange[0]);
    var right = Number(gPlot.zoomRange[1]);
    var center = (left + right) / 2;
    var size = right - left;
    if (e.key == 'ArrowUp')
      size /= 1.05;
    else
      if (e.key == 'ArrowDown')
        size *= 1.05;
    else
      if (e.key == 'ArrowLeft')
        center -= size / 10;
    else
      if (e.key == 'ArrowRight')
        center += size / 10;
    else
      return;
    left = center - size/2;
    right = center + size/2;
    gPlot.setZoomRange([left, right]);
    e.preventDefault();
  });
}

//
// Creates a plot, appends it to <appendto>
// - axis -> { 'AxisName' : 'Nicename', ... }
//
function Plot(appendto) {
  if (!(this instanceof Plot)) {
    logError("Plot() used incorrectly");
    return;
  }

  var axisUnits = [];
  this.unitAxes = {};
  for (var testID in gTests) {
    var unit = gTests[testID].unit;
    if (!(unit in this.unitAxes)) {
      var axisIndex = axisUnits.length;
      axisUnits.push(unit);
      this.unitAxes[unit] = axisIndex;
    }
  }

  this.zoomed = false;

  this.dataRange = gDataRange;
  logMsg("Generating graph, data range - " + JSON.stringify(this.dataRange));
  this.zoomRange = this.dataRange;

  this.container = $.new('div').addClass('graphContainer');
  if (appendto) this.container.appendTo(appendto);
  //$.new('h2').text(name).appendTo(this.container);
  this.rhsContainer = $.new('div').addClass('rhsContainer').appendTo(this.container);
  this.zoomOutButton = $('#zoom-out-button')
    .click(function () {
      self.setZoomRange();
      return false;
    });
  this.legendContainer = $.new('div').addClass('legendContainer').appendTo(this.rhsContainer);

  this.obj = $.new('div').addClass('graph').appendTo(this.container);
  this.flot = $.plot(
    this.obj,
    // Data
    this._buildSeries(this.zoomRange[0], this.zoomRange[1]),
    // Options
    {
      hooks: { draw : [
        function(plot, ctx) {
          var data = plot.getData();
          var offset = plot.getPlotOffset();
          for (var i = 0; i < data.length; i++) {
            var series = data[i];
            for (var j = 0; j < series.data.length; j++) {
              var d = series.data[j];
              if (d[1] === null) continue;
              var buildinf = series.buildinfo[j];
              if ('lastrev' in buildinf)
                continue;
              var color = gDarkColorsFirst[i];
              var x = offset.left + series.xaxis.p2c(d[0]);
              var y = offset.top + series.yaxis.p2c(d[1]);
              var r = 4;
              ctx.lineWidth = 2;
              ctx.beginPath();
              ctx.arc(x,y,r,0,Math.PI*2,true);
              ctx.closePath();
              ctx.fillStyle = color;
              ctx.fill();
            }
          }
        }
      ]},
      series: {
        lines: { show: true },
        points: { show: true }
      },
      grid: {
        color: "#aaa",
        hoverable: true,
        clickable: true
      },
      xaxis: {
        ticks: function(axis) {
          var points = [];
          var range = axis.max - axis.min;
          var d = new Date(axis.min*1000);
          for (var ind in gDateAxisThresholds) {
            var t = gDateAxisThresholds[ind];
            if (range > t.threshold) {
              for (var ind2 in gDateAxisThresholds)
                if (ind2 >= ind)
                  gDateAxisThresholds[ind2].init(d);
              while (d.getTime()/1000 < axis.max) {
                var u = d.getTime()/1000;
                if (u > axis.min) {
                  points.push(u);
                }
                t.next(d);
              }
              break;
            }
          }

          return points;
        },

        tickFormatter: function(val, axis) {
          var range = axis.max - axis.min;
          var date = new Date(val * 1000);

          if (range > 2*24*60*60) {
            var abbrevMonths = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul',
                                'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

            return '<div class="tick-day-month">' + date.getUTCDate() + ' ' +
              abbrevMonths[date.getUTCMonth()] + '</div>' +
              '<div class="tick-year">' + date.getUTCFullYear() + '</div>';
          } else if (range > 2*60) {
            return ('0'+date.getUTCHours()).slice(-2) + ':' + ('0'+date.getUTCMinutes()).slice(-2);
          } else {
            return ('0'+date.getUTCHours()).slice(-2) + ':' + ('0'+date.getUTCMinutes()).slice(-2) + ':' + ('0'+date.getUTCSeconds()).slice(-2);
          }
        }
      },
      yaxes: jQuery.map(axisUnits, function(unit, unitIndex) {
        return {
          ticks: function(axis) {
            // If you zoom in and there are no points to show, axis.max will be
            // very small.  So let's say that we'll always graph at least 32mb.
            var minMax = unit == 'bytes' ? 1 * 1024 : 1000;
            var axisMax = Math.max(axis.max, minMax);

            var approxNumTicks = 10;
            var interval = axisMax / approxNumTicks;

            // Round interval up to nearest power of 2.
            if (unit == 'bytes')
              interval = Math.pow(2, Math.ceil(Math.log(interval) / Math.log(2)));
            else
              interval = Math.pow(10, Math.ceil(Math.log(interval) / Math.log(10)));

            // Round axis.max up to the next interval.
            var max = Math.ceil(axisMax / interval) * interval;

            // Let res be [0, interval, 2 * interval, 3 * interval, ..., max].
            var res = [];
            for (var i = 0; i <= max; i += interval) {
              res.push(i);
            }

            return res;
          },

          tickFormatter: function(val, axis) {
            //return val / (1024 * 1024) + ' MiB';
            return formatUnit(val, unit, axis.max);
          }
        };
      }),
      legend: {
        container: this.legendContainer
      },
      colors: gDarkColorsFirst
    }
  );

  var self = this;

  //
  // Background selector for zooming
  //
  var fcanvas = this.flot.getCanvas();
  this.zoomSelector = $.new('div', null,
                       {
                         top: this.flot.getPlotOffset().top + 'px',
                         height: this.flot.height() - 10 + 'px', // padding-top is 10px
                       })
                       .addClass('zoomSelector')
                       .text("zoom")
                       .insertBefore(fcanvas);

  // For proper layering
  $(fcanvas).css('position', 'relative');

  //
  // Graph Tooltip
  //

  this.tooltip = new Tooltip(this.container);
  this.obj.bind("plotclick", function(event, pos, item) { self.onClick(item); });
  this.obj.bind("plothover", function(event, pos, item) { self.onHover(item, pos); });
  this.obj.bind("mouseout", function(event) { self.hideHighlight(); });

  self.setZoomRange(self.zoomRange, true);
}

// Zoom this graph to given range. If called with no arguments, zoom all the way
// back out. range is of format [x1, x2]. this.dataRange contains the range of
// all data, this.zoomRange contains currently zoomed range if this.zoomed is
// true.
Plot.prototype.setZoomRange = function(range, nosync) {
  var zoomOut = false;
  if (range === undefined)
    range = this.dataRange;
  if (range[0] == this.dataRange[0] && range[1] == this.dataRange[1])
    zoomOut = true;

  var self = this;
  if (this.zoomed && zoomOut) {
    // Zooming back out, remove zoom out button
    this.zoomed = false;
    self.zoomOutButton.hide();
  } else if (!this.zoomed && !zoomOut) {
    // Zoomed out -> zoomed in. Add zoom out button.
    this.zoomed = true;
    self.zoomOutButton.show();
  }

  // If there are sub-series we should pull in that we haven't cached,
  // set requests for them and reprocess the zoom when complete

  this.zoomRange = range;
  var newseries = this._buildSeries(range[0], range[1]);
  this.flot.getAxes().xaxis.options.min = range[0];
  this.flot.getAxes().xaxis.options.max = range[1];
  this.flot.setData(newseries);
  this.flot.setupGrid();
  this.flot.draw();

  // The highlight has the wrong range now that we mucked with the graph
  if (this.highlighted)
    this.showHighlight(this._highlightLoc, this._highlightWidth);

  saveHash();
};

function getCurrentTestIDs() {
  var tests = [];
  for (var testID in gTests) {
    if (testID == gCurrentTestID || testID in gPinnedTestIDs)
      tests.push(testID);
  }
  return tests;
}

// Recreate data with new gCurrentTestID etc.
Plot.prototype.updateData = function() {
  var self = this;
  // Put visible axes on either sides
  var index = 0;
  var configuredUnit = {};
  jQuery.each(getCurrentTestIDs(), function(i, testID) {
    var unit = gTests[testID].unit;
    if (!(unit in configuredUnit)) {
      configuredUnit[unit] = true;
      var axisIndex = self.unitAxes[unit];
      var axis = self.flot.getAxes()['y' + (axisIndex ? 1 + axisIndex : '') + 'axis'];
      axis.options.position = ['left', 'right'][index++ % 2];
    }
  });

  var range = this.zoomRange;
  var newseries = this._buildSeries(range[0], range[1]);
  this.flot.setData(newseries);
  this.flot.setupGrid();
  this.flot.draw();
};

// Takes two timestamps and builds a list of series based on this plot's axis
// suitable for passing to flot - condensed to try to hit gMaxPoints.
Plot.prototype._buildSeries = function(start, stop) {
  var self = this;

  // Grouping distance
  var groupDistance = gMaxPoints == 0 ? 0 : Math.round((stop - start) / gMaxPoints);

  // Render one commit out-of-bound of zoom level,
  // so that there is a visible line going off-screen.
  var startIndex = -1;
  var stopIndex = gData.commits.length;
  var commit, commitIndex;
  for (commitIndex = 0; commitIndex < gData.commits.length; commitIndex++) {
    commit = gData.commits[commitIndex];

    if (start !== undefined && commit.time >= start && startIndex < 0) {
      startIndex = Math.max(0, commitIndex - 1);
    }
    if (stop !== undefined && commit.time > stop) {
      stopIndex = commitIndex + 1;
      break;
    }
  }
  startIndex = Math.max(0, startIndex);

  var seriesData = [];

  getCurrentTestIDs().forEach(function(testID) {
    var testData = [];
    var testMetadata = [];

    function pushNode(time, y, metadata) {
      testData.push([ time, y ]);
      testMetadata.push(metadata);
    }
    // Null data points indicate gaps in the data,
    // and break the line in the Flot chart.
    function pushNull(time) {
      pushNode(time, null, null);
    }

    // Push a datapoint (one or more commits) onto builds/data
    function pushDataPoint(pointData, pointMetadata, ctime, allValues) {
      if (!pointData)
        return;

      if (pointData.length) {
        var i, value;
        var min = null, minIndex, max = null, maxIndex;
        for (i = 0; i < allValues.length; i++) {
          value = allValues[i];
          if (value === null)
            continue;
          if (min === null || min > value) {
            min = value;
            minIndex = i;
          }
          if (max === null || max < value) {
            max = value;
            maxIndex = i;
          }
        }
        var sawNull = false;
        var lastValue = null;
        for (i = 0; i < allValues.length; i++) {
          value = allValues[i];
          if (value === null)
            sawNull = true;
          else
            if (i == 0 || i == minIndex || i == maxIndex || i + 1 == allValues.length) {
              if (sawNull)
                pushNull(ctime);
              sawNull = false;
              if (value != lastValue)
                pushNode(ctime, value, pointMetadata);
              lastValue = value;
            }
        }
        if (sawNull)
          pushNull(ctime);
      } else {
        pushNull(ctime);
      }
    }

    function groupTime(timestamp) {
      return groupDistance > 0 ? timestamp - (timestamp % groupDistance) : timestamp;
    }

    var pointData = null;
    var pointMetadata = null;
    var ctime = -1;
    var allValues = [];

    for (var commitIndex = 0; commitIndex < gData.commits.length; commitIndex++) {
      var commit = gData.commits[commitIndex];

      if (commitIndex < startIndex) continue;
      if (commitIndex >= stopIndex) break;

      var time;
      if (gQueryVars['evenspacing']) {
        time = start + commitIndex * (stop - start) / gData.commits.length;
      } else {
        time = groupTime(commit.time);
      }

      var testIndex;
      if (time != ctime) {
        pushDataPoint(pointData, pointMetadata, ctime, allValues);
        ctime = time;
        pointData = [];
        pointMetadata = {};
        allValues = [];
      }

      var value = null;
      if (testID in commit.results) {
        var result = commit.results[testID];
        if (result.error === null)
          value = result.value;
      }

      if (value !== null) {
        pointData.push(value);
        if (!pointMetadata['firstrev']) {
          pointMetadata['firstrev'] = commit.commit;
          pointMetadata['timerange'] = [ commit.time, commit.time ];
          pointMetadata['numrevs'] = 1;
        } else {
          pointMetadata['lastrev'] = commit.commit;
          pointMetadata['timerange'][1] = commit.time;
          pointMetadata['numrevs']++;
        }
      }
      allValues.push(value);
    }
    pushDataPoint(pointData, pointMetadata, ctime, allValues);

    if (testData.length != testMetadata.length)
      alert('data/buildinfo length mismatch');

    seriesData.push({
      name: testID,
      label: gTests[testID].name,
      data: testData,
      buildinfo: testMetadata,
      yaxis: 1 + self.unitAxes[gTests[testID].unit]
    });
  });

  return seriesData;
};

Tooltip.prototype.handleClick = function() {
  var self = this;
  var build = this.build_set[this.build_index];

  if ('lastrev' in build) {
    // Multiple commits - open commit list on Bitbucket d.git repo
    window.open(gitRangeURL(build['firstrev'], build['lastrev']), '_blank');
  } else {
    // Single commit - go to the GitHub pull request page
    window.open(gitURL(build['firstrev']), '_blank');
  }
};

// Either zoom in on a datapoint or trigger a graph zoom or do nothing.
Plot.prototype.onClick = function(item) {
  if (item) {
    // Clicked an item, switch tooltip to build detail mode
    this.tooltip.handleClick();
  } else if (this.highlighted) {
    // Clicked on highlighted zoom space, do a graph zoom
    this.setZoomRange(this.highlightRange);
  }
};

// Shows the zoom/highlight bar centered [location] pixels from the left of the
// graph.
//
// EX To turn a mouse event into graph coordinates:
// var location = event.pageX - this.flot.offset().left
//                + this.flot.getPlotOffset().left;
Plot.prototype.showHighlight = function(location, width) {
  if (!this.highlighted) {
    this.zoomSelector.stop().fadeTo(250, 1);
    this.highlighted = true;
  }

  this._highlightLoc = location;
  this._highlightWidth = width;

  var xaxis = this.flot.getAxes().xaxis;
  var off = this.flot.getPlotOffset();
  var left = location - width / 2;
  var overflow = left + width - this.flot.width() - off.left;
  var underflow = off.left - left;

  if (overflow > 0) {
    width = Math.max(width - overflow, 0);
  } else if (underflow > 0) {
    left += underflow;
    width = Math.max(width - underflow, 0);
  }

  // Calculate the x-axis range of the data we're highlighting
  this.highlightRange = [ xaxis.c2p(left - off.left), xaxis.c2p(left + width - off.left) ];

  this.zoomSelector.css({
    left: left + 'px',
    width: width + 'px'
  });
};

Plot.prototype.hideHighlight = function() {
  if (this.highlighted) {
    this.highlighted = false;
    this.zoomSelector.stop().fadeTo(250, 0);
  }
};

// If we're hovering over a point, show a tooltip. Otherwise, show the
// zoom selector if we're not beyond our zoom-in limit
Plot.prototype.onHover = function(item, pos) {
  var self = this;
  if (item &&
      (!this.hoveredItem || (item.dataIndex !== this.hoveredItem.dataIndex))) {
    this.hideHighlight();
    this.tooltip.showBuild(item.series.label,
                           item.series.data,
                           item.series.buildinfo,
                           item.dataIndex,
                           item.series.name,
                           item.seriesIndex);

    // Tooltips move relative to the graphContainer
    var offset = this.container.offset();
    this.tooltip.hover(item.pageX - offset.left, item.pageY - offset.top, this.hoveredItem ? true : false);
  } else if (!item) {
    if (this.hoveredItem) {
      // Only send unhover to the tooltip after we have processed all
      // graphhover events, and the tooltip has processed its mouseover events
      window.setTimeout(function () {
        if (!self.hoveredItem) {
          self.tooltip.unHover();
        }
      }, 0);
    }
    // Move hover highlight for zooming
    var left = pos.pageX - this.flot.offset().left + this.flot.getPlotOffset().left;
    this.showHighlight(left, gHighlightWidth);
  }
  this.hoveredItem = item;
};

$(function () {
  var url = 'data/data.json';
  $.ajax({
    url: url,
    xhr: dlProgress,
    success: function (data) {
      //
      // Graph data arrived, do additional processing and create plots
      //
      gData = data;

      // Calculate gDataRange.  The full range of gGraphData can have a number
      // of superfluous builds that have null for all series values we care
      // about. For instance, the mobile series all start Dec 2012, so all
      // builds prior to that are not useful in mobile mode.
      gDataRange = [ null, null ];
      var commitIdx, testIdx, resultIdx;
      for (commitIdx = 0; commitIdx < gData.commits.length; commitIdx++) {
        var t = gData.commits[commitIdx].time;
        if (gDataRange[0] === null || t < gDataRange[0])
          gDataRange[0] = t;
        if (gDataRange[1] === null || t > gDataRange[1])
          gDataRange[1] = t;
      }
      if (gDataRange[0] === null || gDataRange[1] === null) {
        logError("No valid data in the full range!");
      } else if (gDataRange[0] == gDataRange[1]) {
        // Only one timestamp, bump the range out around it so flot does not
        // have a heart attack
        gDataRange[0] -= 60 * 60 * 24 * 7;
        gDataRange[1] += 60 * 60 * 24 * 7;
      }
      logMsg("Useful data range is [ " + gDataRange + " ]");

      gCommits = {};
      for (commitIdx = 0; commitIdx < gData.commits.length; commitIdx++) {
        var commit = gData.commits[commitIdx];
        commit.next = commit.prev = null;
        gCommits[commit.commit] = commit;
        commit.results = {};
        if (commitIdx > 0) {
          var prevCommit = gData.commits[commitIdx-1];
          prevCommit.next = commit;
          commit.prev = prevCommit;
        }
      }

      gTests = {};
      for (testIdx = 0; testIdx < gData.tests.length; testIdx++) {
        var test = gData.tests[testIdx];
        gTests[test.id] = test;
      }

      for (resultIdx = 0; resultIdx < gData.results.length; resultIdx++) {
        var result = gData.results[resultIdx];
        if (result.commit in gCommits)
          gCommits[result.commit].results[result.testID] = result;
      }

      $('#graphs h3').remove();
      gPlot = new Plot($('#graphs'));

      $(window).on('hashchange', function(e) {
        if (!suppressHashChange)
          applyHash();
      });
      applyHash();

      // Show stats
      var stats =
          '<span>' +
          'Have ' + data.stats.numCommits +
          ' commits (since ' + data.stats.lastCommitTime + '), ' +
          data.stats.numCachedCommits + ' built (' + Math.trunc(data.stats.numCachedCommits * 100 / data.stats.numCommits) + '%)' +
          '</span> | <span>' +
          'Test coverage: ' + Math.trunc(data.stats.numResults * 100 / (data.tests.length * data.stats.numCommits)) +
          '%</span>';
      $('#page-footer').html(stats);
    },
    error: function(xhr, status, error) {
      $('#graphs h3').text("An error occured while loading the graph data (" + url + ")");
      $('#graphs').append($.new('p', null, { 'text-align': 'center', color: '#F55' }).text(status + ': ' + error));
    },
    dataType: 'json'
  });

  $('#pin').change(function() {
    if (this.checked)
      gPinnedTestIDs[gCurrentTestID] = true;
    else
      delete gPinnedTestIDs[gCurrentTestID];
    saveHash();
  });

  $('#reset-button').click(function() {
    window.location.hash = '';
  });

  var adjectives = ['slim', 'fast', 'lean'];
  var adjectiveIndex = 0;
  var rotating = false;
  function rotateAdjective() {
    if (rotating) return;
    rotating = true;
    $('#header-slim').html(adjectives[adjectiveIndex] + '<br>' + adjectives[(adjectiveIndex+1)%3]);
    $('#header-slim').css('scrollTop', 100);
    $('#header-slim').animate({
      scrollTop: 100//$(".middle").offset().top
    }, 1000, function() { rotating = false; });
    adjectiveIndex = (adjectiveIndex+1)%3;
  }
  $('#page-header').click(rotateAdjective);
});

function selectTest(testID) {
  if (testID in gTests)
    createTestSelectors(gTests[testID].name.split(' - '));
  else
    alert('Unknown test: ' + testID);
}

function createTestSelectors(targetPath) {
  var $testSelectors = $('#test-selectors');
  $testSelectors.empty();

  var path = [];

  while (true) {
    var children = [];
    var haveChild = {};
    var selectionIndex = 0;
    var i;

    testLoop:
    for (var testID in gTests) {
      var testPath = gTests[testID].name.split(" - ");

      // Is this test on our path?
      for (i = 0; i < path.length; i++)
        if (i >= testPath.length || testPath[i] != path[i])
          continue testLoop;

      // There is a test with this exact name,
      // and we've built the dropdowns to it,
      // so we're done.
      if (testPath.length == path.length) {
        _renderTest(testID);
        return;
      }

      var child = testPath[path.length];
      if (!(child in haveChild)) {
        if (path.length < targetPath.length && targetPath[path.length] == child)
          selectionIndex = children.length;
        haveChild[child] = true;
        children.push(child);
      }
    }

    var $testSelector = $.new('select');
    for (i = 0; i < children.length; i++) {
      var $option = $.new('option', {'value' : children[i]}).text(children[i]);
      if (i == selectionIndex)
        $option.attr('selected', 'selected');
      $testSelector.append($option);
    }
    (function() {
      var idx = path.length;
      $testSelector.on('change keyup', function() {
        var newPath = [];
        $testSelectors.find('select').each(function(i, e) {
          newPath.push($(e).val());
        });
        createTestSelectors(newPath);
        var selectors = $testSelectors.find('select');
        // Restore focus
        if (idx < selectors.length)
          selectors[idx].focus();
      });
    }());
    $testSelectors.append($testSelector);

    path.push(children[selectionIndex]);
  }
}

function _renderTest(testID) {
  gCurrentTestID = testID;
  gPlot.updateData();
  saveHash();
  $('#pin').prop('checked', testID in gPinnedTestIDs);
  $('#test-id').text(testID);
  $('#test-name').text(gTests[testID].name.replace(/ - /g, ' – '));
  $('#test-description').html(gTests[testID].description);
}

function getCurrentHash() {
  return '#' + [gCurrentTestID, Object.keys(gPinnedTestIDs).join(','), gPlot.zoomRange[0], gPlot.zoomRange[1]].join(';');
}
var suppressHashChange = false;
function saveHash() {
  if (gPlot && !suppressHashChange) {
    suppressHashChange = true;
    window.location.hash = getCurrentHash();
    suppressHashChange = false;
  }
}

function applyHash() {
  var hash = window.location.hash;
  if (hash == getCurrentHash())
    return;
  hash = hash.substr(1).split(';');
  suppressHashChange = true;
  if (hash.length == 1 && hash[0] == '') {
    gPinnedTestIDs = {};
    selectTest(gDefaultTestID);
    gPlot.setZoomRange();
  } else if (hash.length == 4) {
    gPinnedTestIDs = {};
    hash[1].split(',').forEach(function(testID) {
      if (testID.length)
        gPinnedTestIDs[testID] = true;
    });
    selectTest(hash[0]);
    gPlot.setZoomRange([hash[2], hash[3]]);
  }
  suppressHashChange = false;
}
