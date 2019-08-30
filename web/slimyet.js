/* -*- fill-column: 80; js-indent-level: 2; -*- */
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
    expand(document.location.search.slice(1), '&', '=')
  if (document.location.hash)
    expand(document.location.hash.slice(1), ',', ':')
  return ret;
})();

/*
 * Annotations to draw on the graph. Format:
 */

var gAnnotations = (function() {
  var annotations = [
    /*TODO*/
  ];

  // Sort by date
  annotations.sort(function(a, b) {
    a = a['date'].getTime();
    b = b['date'].getTime();
    return (a < b) ? -1 : (a == b) ? 0 : 1;
  });
  return annotations;
})();

// Width in pixels of highlight (zoom) selector
var gHighlightWidth = gQueryVars['zoomwidth'] ? +gQueryVars['zoomwidth'] : 400;

// Offset between tooltip and cursor
var gTooltipOffset = 'tooltipoffset' in gQueryVars ? +gQueryVars['tooltipoffset'] : 10;

// Coalesce datapoints to keep them under this many per zoom level.
// Default to 150, or 0 (disabled) if nocondense is supplied
var gMaxPoints = gQueryVars['maxpoints'] ? +gQueryVars['maxpoints'] : (gQueryVars['nocondense'] ? 0 : 150);

// Merge tooltips if their position is within this many pixels
var gAnnoMergeDist = 'annotationmerge' in gQueryVars ? +gQueryVars['annotationmerge'] : 50;

// How many xaxis ticks there should be, ticks will be averaged to this density
var gTickDensity = 'tickdensity' in gQueryVars ? +gQueryVars['tickdensity'] : 20;

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

// Dates mozilla-central *branched* to form various release trees. Used to
// determine date placement on the X-axis of graphs
// See: https://wiki.mozilla.org/RapidRelease/Calendar
var gReleases = [
  /* TODO */
  /*
  {dateStr: "2011-03-03", name: "Fx 4"},
  {dateStr: "2011-04-12", name: "Fx 5"},
  {dateStr: "2011-05-24", name: "Fx 6"},
  {dateStr: "2011-07-05", name: "Fx 7"},
  {dateStr: "2011-08-16", name: "Fx 8"},
  {dateStr: "2011-09-27", name: "Fx 9"},
  {dateStr: "2011-11-08", name: "Fx 10"},
  {dateStr: "2011-12-20", name: "Fx 11"},
  {dateStr: "2012-01-31", name: "Fx 12"},
  {dateStr: "2012-03-13", name: "Fx 13"},
  {dateStr: "2012-04-24", name: "Fx 14"},
  {dateStr: "2012-06-05", name: "Fx 15"},
  {dateStr: "2012-07-16", name: "Fx 16"},
  {dateStr: "2012-08-27", name: "Fx 17"},
  {dateStr: "2012-10-08", name: "Fx 18"},
  {dateStr: "2012-11-19", name: "Fx 19"},
  {dateStr: "2013-01-07", name: "Fx 20"},
  {dateStr: "2013-02-18", name: "Fx 21"},
  {dateStr: "2013-04-01", name: "Fx 22"},
  {dateStr: "2013-05-13", name: "Fx 23"},
  {dateStr: "2013-06-24", name: "Fx 24"},
  {dateStr: "2013-08-05", name: "Fx 25"},
  {dateStr: "2013-09-16", name: "Fx 26"},
  {dateStr: "2013-10-28", name: "Fx 27"},
  {dateStr: "2013-12-09", name: "Fx 28"},
  {dateStr: "2014-02-03", name: "Fx 29"},
  {dateStr: "2014-03-17", name: "Fx 30"},
  {dateStr: "2014-04-28", name: "Fx 31"},
  {dateStr: "2014-06-09", name: "Fx 32"},
  {dateStr: "2014-07-21", name: "Fx 33"},
  {dateStr: "2014-09-02", name: "Fx 34"},
  {dateStr: "2014-10-13", name: "Fx 35"},
  {dateStr: "2014-11-24", name: "Fx 36"},
  {dateStr: "2015-01-12", name: "Fx 37"},
  {dateStr: "2015-02-23", name: "Fx 38"},
  {dateStr: "2015-04-06", name: "Fx 39"},
  {dateStr: "2015-05-18", name: "Fx 40"},
  {dateStr: "2015-06-29", name: "Fx 41"},
  {dateStr: "2015-08-10", name: "Fx 42"}
  */
];

// Create gReleases[x].date objects
(function() {
  for (var i = 0; i < gReleases.length; i++) {
    // Seconds from epoch.
    gReleases[i].date = Date.parse(gReleases[i].dateStr) / 1000;
  }
})();

// Lookup gReleases by date
var gReleaseLookup = function() {
  var lookup = {};
  for (var i = 0; i < gReleases.length; i++) {
    lookup[gReleases[i].date] = gReleases[i].name;
  }
  return lookup;
}();


// Contents of data.json
var gData;

// Key data lookup
var gCommits = {};
var gTests = {};

// Current test
var gCurrentTestID = 'program-hello-binarysize';

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
      window.console.error(obj)
    else if (window.console.log)
      window.console.log("ERROR: " + obj);
  }
}

// Takes a second-resolution unix timestamp, prints a UTCDate. If the date
// is exactly midnight, remove the "00:00:00 GMT" (we have a lot of timestamps
// condensed to day-resolution)
function prettyDate(aTimestamp) {
  // If the date is exactly midnight, remove the time portion.
  // (overview data is coalesced by day by default)
  return new Date(aTimestamp * 1000).toUTCString().replace('00:00:00 GMT', '');
}

function mkDelta(mem, lastmem) {
  var delta = mem - lastmem;
  var obj = $.new('span').addClass('delta');
  if (delta < 0) {
    obj.text('Δ -'+formatUnit(-delta));
    obj.addClass('neg');
  } else if (delta == 0) {
    obj.text('Δ '+formatUnit(delta));
    obj.addClass('equ');
  } else {
    obj.text('Δ '+formatUnit(delta));
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
  } else {
    return prettyFloat(raw / Math.pow(1000, 2)) + "M";
  }
}

function formatUnit(raw, unit, ref) {
  if (!unit) unit = gTests[gCurrentTestID].unit;
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

// Round unix timestamp to the nearest midnight UTC. (Not *that day*'s midnight)
function roundDay(date) {
  return Math.round(date / (24 * 60 * 60)) * 24 * 60 * 60;
}

// Round a date (seconds since epoch) up to the next day.
function roundDayUp(date) {
  return Math.ceil(date / (24 * 60 * 60)) * 24 * 60 * 60;
}

// Round a date (seconds since epoch) down to the previous day.
function roundDayDown(date) {
  return Math.floor(date / (24 * 60 * 60)) * 24 * 60 * 60;
}

// Get the full time range covered by two (possibly condensed) build_info structs
function getBuildTimeRange(firstbuild, lastbuild)
{
  var range = [];
  if ('timerange' in firstbuild && firstbuild['timerange'][0] < firstbuild['time'])
    range.push(firstbuild['timerange'][0]);
  else
    range.push(firstbuild['time']);

  if ('timerange' in lastbuild && lastbuild['timerange'][1] > lastbuild['time'])
    range.push(lastbuild['timerange'][1]);
  else
    range.push(lastbuild['time']);

  return range;
}


//
// Tooltip
//

// A tooltip that can be positioned relative to its parent via .hover(),
// or 'zoomed' to inflate and cover its parent via .zoom()
function Tooltip(parent) {
  if ((!this instanceof Tooltip)) {
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
    if (self.obj.is(":visible") && !self.hovered && !self.isZoomed()) {
      self._fadeOut();
    }
  });

  this.obj.data('owner', this);
  this.hovered = false;
  this.onUnzoomFuncs = [];
  this.faded = true;
}

Tooltip.prototype.isZoomed = function () { return this.obj.is('.zoomed'); }

Tooltip.prototype.append = function(obj) {
  this.content.append(obj);
}

Tooltip.prototype.empty = function() {
  this.content.empty();
  this.seriesname = null;
  this.buildset = null;
  this.buildindex = null;
}

Tooltip.prototype.hover = function(x, y, nofade) {
  if (this.isZoomed())
    return;

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
}

Tooltip.prototype.unHover = function() {
  if (this.isZoomed())
    return;
  this.hovered = false;
  if (!this.mouseover) {
    // Don't actually fade till the mouse goes away, see handlers in constructor
    this._fadeOut();
  }
}

Tooltip.prototype._fadeIn = function() {
  if (this.faded) {
    this.obj.stop().fadeTo(200, 1);
    this.faded = false;
  }
}

Tooltip.prototype._fadeOut = function() {
  this.faded = true;
  this.obj.stop().fadeTo(200, 0, function () { $(this).hide(); });
}

// value      - Value of displayed point
// label      - tooltip header/label
// buildset   - set of builds shown for this graph (different from gBuildInfo as
//              it may have been condensed)
// buildindex - index of this build in buildset
// series     - the series we are showing
Tooltip.prototype.showBuild = function(label, series, buildset, buildindex, seriesname) {
  this.empty();
  this.build_series = series;
  this.build_seriesname = seriesname;
  this.build_set = buildset;
  this.build_index = buildindex;

  var value = series[buildindex][1];
  var build = buildset[buildindex];
  var rev = build['firstrev'];

  // Label
  //this.append($.new('h3').text(label));
  // Build link / time
  var ttinner = $.new('p');
  var valobj = $.new('p').text(formatUnit(value) + ' ');
  // Delta
  if (buildindex > 0 && series[buildindex - 1][1] !== null) {
    valobj.append(mkDelta(value, series[buildindex - 1][1]));
  }
  ttinner.append(valobj);
  if (!build['lastrev']) {
    ttinner.append($.new('b').text('commit '));
    ttinner.append(mkGitLink(rev));
    ttinner.append($.new('p').addClass('timestamp').text(prettyDate(build['timerange'][0])));
    ttinner.append($.new('p').addClass('commit-message').text(gCommits[rev].message));
  } else {
    // Multiple revisions, add range link
    ttinner.append($.new('b').text('commit range'));
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
  this.append(ttinner);
}

Tooltip.prototype.onUnzoom = function(callback) {
  if (this.isZoomed())
    this.onUnzoomFuncs.push(callback);
}

Tooltip.prototype.unzoom = function() {
  if (this.isZoomed() && !this.obj.is(':animated'))
  {
    var w = this.obj.parent().width();
    var h = this.obj.parent().height();
    var self = this;
    this.obj.animate({
        width: Math.round(0.5 * w) + 'px',
        height: Math.round(0.5 * h) + 'px',
        top: Math.round(0.25 * h) + 'px',
        left: Math.round(0.25 * w) + 'px',
        opacity: '0'
      }, 250, function() {
        self.obj.removeAttr('style').hide().removeClass('zoomed');
        self.obj.find('.closeButton').remove();
    });

    var callback;
    while (callback = this.onUnzoomFuncs.pop())
      callback.apply(this);

    var url;
    while (url = gObjectURLs.pop()) {
      window.URL.revokeObjectURL(url);
    }
  }
}

//
// Ajax for getting more graph data
//

// Fetch the series given by name (see gGraphData['allseries']), call success
// or fail callback. Can call these immediately if the data is already available
var gPendingFullData = {}
function getFullSeries(dataname, success, fail) {
  if (dataname in gFullData) {
    if (success instanceof Function)
      window.setTimeout(success, 0);
  } else {
    if (!(dataname in gPendingFullData)) {
      gPendingFullData[dataname] = { 'success': [], 'fail': [] };
      $.ajax({
        xhr: dlProgress,
        url: '/data/' + dataname + '.json',
        success: function (data) {
          gFullData[dataname] = data;
          for (var i in gPendingFullData[dataname]['success'])
            gPendingFullData[dataname]['success'][i].call(null);
          delete gPendingFullData[dataname];
        },
        error: function(xhr, status, error) {
          for (var i in gPendingFullData[dataname]['fail'])
            gPendingFullData[dataname]['fail'][i].call(null, error);
          delete gPendingFullData[dataname];
        },
        dataType: 'json'
      });
    }
    if (success) gPendingFullData[dataname]['success'].push(success);
    if (fail) gPendingFullData[dataname]['fail'].push(fail);
  }
}

// Fetch the full memory dump for a build. Calls success() or fail() callbacks
// when the data is ready (which can be before the call even returns)
// (gets /data/<buildname>.json)
function getPerBuildData(buildname, success, fail) {
  if (gPerBuildData[buildname] !== undefined) {
    if (success instanceof Function) success.apply(null);
  } else {
    $.ajax({
      xhr: dlProgress,
      url: '/data/' + buildname + '.json',
      success: function (data) {
        gPerBuildData[buildname] = data;
        if (success instanceof Function) success.call(null);
      },
      error: function(xhr, status, error) {
        if (fail instanceof Function) fail.call(null, error);
      },
      dataType: 'json'
    });
  }
}

var gDateAxisThresholds = [
  { threshold : 720*24*60*60, init : function(d) { d.setMonth       (0); }, next : function(d) { d.setFullYear(d.getFullYear()+1); }},
  { threshold :  30*24*60*60, init : function(d) { d.setDate        (1); }, next : function(d) { d.setMonth   (d.getMonth   ()+1); }},
//{ threshold :  10*24*60*60, init : function(d) { d.setDate(d.getDate()-d.getDay()); }, next : function(d) { d.setDate(d.getDate()+7); }},
  { threshold :   1*24*60*60, init : function(d) { d.setHours       (0); }, next : function(d) { d.setDate    (d.getDate    ()+1); }},
  { threshold :      1*60*60, init : function(d) { d.setMinutes     (0); }, next : function(d) { d.setHours   (d.getHours   ()+1); }},
  { threshold :         1*60, init : function(d) { d.setSeconds     (0); }, next : function(d) { d.setMinutes (d.getMinutes ()+1); }},
  { threshold :            1, init : function(d) { d.setMilliseconds(0); }, next : function(d) { d.setSeconds (d.getSeconds ()+1); }},
];

//
// Plot functions
//

//
// Creates a plot, appends it to <appendto>
// - axis -> { 'AxisName' : 'Nicename', ... }
//
function Plot(appendto) {
  if (!(this instanceof Plot)) {
    logError("Plot() used incorrectly");
    return;
  }

  this.axis = {};
  for (var testID in gTests)
    this.axis[testID] = gTests[testID].name;
  this.zoomed = false;

  this.dataRange = gDataRange;
  logMsg("Generating graph \""+name+"\", data range - " + JSON.stringify(this.dataRange));
  this.zoomRange = this.dataRange;

  this.container = $.new('div').addClass('graphContainer');
  if (appendto) this.container.appendTo(appendto);
  //$.new('h2').text(name).appendTo(this.container);
  this.rhsContainer = $.new('div').addClass('rhsContainer').appendTo(this.container);
  this.zoomOutButton = $.new('a', { href: '#', class: 'zoomOutButton' })
                        .appendTo($('#zoomOutButtonContainer'))
                        .text('Zoom Out')
                        .hide()
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
          var axes = plot.getAxes();
          var offset = plot.getPlotOffset();
          for (var i = 0; i < data.length; i++) {
            var series = data[i];
            for (var j = 0; j < series.data.length; j++) {
              var buildinf = series.buildinfo[j];
              if ('lastrev' in buildinf)
                continue;
              var color = gDarkColorsFirst[0];
              var d = series.data[j];
              if (d[1] === null) continue;
              var x = offset.left + axes.xaxis.p2c(d[0]);
              var y = offset.top + axes.yaxis.p2c(d[1]);
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
          /*
          var prevdate = 0;
          for (var i = 0; i < gReleases.length; i++) {
            var date = gReleases[i].date;
            var dist = date - prevdate;
            if (axis.min <= date && date <= axis.max &&
                dist >= range / gTickDensity) {
              points.push(date);
              prevdate = date;
            }
          }

          if (points.length >= 2) {
            return points;
          }

          if (points.length == 1) {
            var minDay = roundDayUp(axis.min);
            var maxDay = roundDayDown(axis.max);

            if (Math.abs(points[0] - minDay) > Math.abs(points[0] - maxDay)) {
              points.push(minDay);
            }
            else {
              points.push(maxDay);
            }

            return points;
          }

          points.push(roundDayUp(axis.min));
          points.push(roundDayDown(axis.max));
          */
          var d = new Date(roundDayDown(axis.min)*1000);
          for (var ind in gDateAxisThresholds) {
            var t = gDateAxisThresholds[ind];
            if (range > t.threshold) {
              for (var ind2 in gDateAxisThresholds)
                if (ind2 >= ind)
                  gDateAxisThresholds[ind2].init(d);
              while (d.getTime()/1000 < axis.max) {
                var u = roundDayDown(d.getTime()/1000);
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
          var abbrevMonths = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul',
                              'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
          var date = new Date(val * 1000);

          var releaseName = "";
          if (gReleaseLookup[val]) {
            releaseName = '<div class="tick-release-name">' + gReleaseLookup[val] + '</div>';
          }

          return '<div class="tick-day-month">' + date.getUTCDate() + ' ' +
            abbrevMonths[date.getUTCMonth()] + '</div>' +
            '<div class="tick-year">' + date.getUTCFullYear() + '</div>' +
            releaseName;
        }
      },
      yaxis: {
        ticks: function(axis) {
          // If you zoom in and there are no points to show, axis.max will be
          // very small.  So let's say that we'll always graph at least 32mb.
          var minMax = gTests[gCurrentTestID].unit == 'bytes' ? 1 * 1024 : 1000;
          var axisMax = Math.max(axis.max, minMax);

          var approxNumTicks = 10;
          var interval = axisMax / approxNumTicks;

          // Round interval up to nearest power of 2.
          if (gTests[gCurrentTestID].unit == 'bytes')
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
          return formatUnit(val, gTests[gCurrentTestID].unit, axis.max);
        }
      },
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

  // Setup annotations container
  var offset = this.flot.getPlotOffset();
  this.annotations = $.new('div').addClass('annotations')
                      .css('width', this.flot.width() + 'px')
                      .css('left', offset.left + 'px')
                      .css('top', offset.top + 'px');
  this.obj.prepend(this.annotations);
  this._drawAnnotations();

  this.tooltip = new Tooltip(this.container);
  var self = this;
  this.obj.bind("plotclick", function(event, pos, item) { self.onClick(item); });
  this.obj.bind("plothover", function(event, pos, item) { self.onHover(item, pos); });
  this.obj.bind("mouseout", function(event) { self.hideHighlight(); });

  self.setZoomRange(self.zoomRange, true);
}

// Zoom this graph to given range. If called with no arguments, zoom all the way
// back out. range is of format [x1, x2]. this.dataRange contains the range of
// all data, this.zoomRange contains currently zoomed range if this.zoomed is
// true.
// If the specified range warrents fetching full data (getFullSeries), but we
// don't have it, issue the ajax and set a callback to re-render the graph when
// it returns (so we'll zoom in, but then re-render moments later with more
// points)
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
    this.flot.setData(newseries);
    this.flot.setupGrid();
    this.flot.draw();
    this._drawAnnotations();

    // The highlight has the wrong range now that we mucked with the graph
    if (this.highlighted)
      this.showHighlight(this._highlightLoc, this._highlightWidth);
}

// Recreate data with new gCurrentTestID etc.
Plot.prototype.updateData = function() {
    var range = this.zoomRange;
    var newseries = this._buildSeries(range[0], range[1]);
    this.flot.setData(newseries);
    this.flot.setupGrid();
    this.flot.draw();
    this._drawAnnotations();
}

// Takes two timestamps and builds a list of series based on this plot's axis
// suitable for passing to flot - condensed to try to hit gMaxPoints.
Plot.prototype._buildSeries = function(start, stop) {
  var self = this; // for closures

  // Push a dummy null point at the beginning of the series to force the zoom to
  // start exactly there

  var builds = [ { time: start, timerange: [ start, start ] } ];
  var data = {};

  var testIDs = [gCurrentTestID];
  testIDs.forEach(function(axis) {
    data[gCurrentTestID] = [ [ start, null ] ];
  });

  // Grouping distance
  var groupdist = gMaxPoints == 0 ? 0 : Math.round((stop - start) / gMaxPoints);

  function pushNull(time) {
    builds.push({ time: time, timerange: [ time, time ] });
    testIDs.forEach(function(axis) {
      data[axis].push([ time, null ]);
    });
  }

  function pushdp(series, buildinf, ctime, haveNull, haveNonNull) {
    // Push a datapoint (one or more commits) onto builds/data
    if (ctime != -1) {
      // Flatten the axis first and determine if this is a null build
      var flat = {};
      for (var axis in series)
        flat[axis] = flatten(series[axis]);

      if (haveNull) {
        // Add null DP to break the line.
        pushNull(buildinf['timerange'][0]);
      }
      if (haveNonNull) {
        // Add to series
        builds.push(buildinf);
        testIDs.forEach(function(axis) {
          data[axis].push([ +buildinf['time'], flat[axis] ]);
        });

        if (haveNull) {
          // Add null DP to break the line.
          pushNull(buildinf['timerange'][1]);
        }
      }
    }
  }
  function groupin(timestamp) {
    return groupdist > 0 ? timestamp - (timestamp % groupdist) : timestamp;
  }
  // Given a list of numbers, return [min, median, max]
  function flatten(series) {
    var iseries = [];
    for (var x in series) {
      if (series[x] !== null) {
        if (series[x] instanceof Array) {
          // [ median, count ] pair, push it N times for weighting (this is not
          // the most efficient way to do this)
          for (var i = 0; i < series[x][1]; i++)
            iseries.push(+series[x][0]);
        } else {
          iseries.push(+series[x]);
        }
      }
    }
    if (!iseries.length) return null;
    iseries.sort();
    var median;
    if (iseries.length % 2)
      median = iseries[(iseries.length - 1)/ 2];
    else
      median = iseries[iseries.length / 2];
    return median;
  }

  var buildinf;
  var series = {};
  var ctime = -1;
  var haveNull;
  var haveNonNull;

  for (var commitIndex in gData.commits) {
    var commit = gData.commits[commitIndex];
    for (var testIndex in testIDs) {
      var testID = testIDs[testIndex];

      if (start !== undefined && commit.time < start) continue;
      if (stop !== undefined && commit.time > stop) break;

      var time;
      if (gQueryVars['evenspacing']) {
        time = start + commitIndex * (stop - start) / gData.commits.length;
      } else {
        time = groupin(commit.time);
      }

      if (time != ctime) {
        pushdp(series, buildinf, ctime, haveNull, haveNonNull);
        ctime = time;
        series = {};
        buildinf = { time: time };
        haveNull = false;
        haveNonNull = false;
      }

      // Full series uses non-merged syntax, which is just build['revision']
      // but we might be using overview data and hence merged syntax
      // (firstrev, lastrev)
      var rev = commit.commit;
      var starttime = commit.time;
      var endtime = commit.time;
      if (!buildinf['firstrev']) {
        buildinf['firstrev'] = rev;
        buildinf['timerange'] = [ starttime, endtime ];
      } else {
        buildinf['lastrev'] = rev;
        buildinf['timerange'][1] = endtime;
      }
      testIDs.forEach(function(axis) {
        var value = null;
        if (axis in commit.results) {
          var result = commit.results[axis];
          if (result.error === null)
            value = result.value;
        }

        if (!series[axis]) series[axis] = [];
        // Push all non-null datapoints onto list, pushdp() flattens
        // this list, finding its midpoint/min/max.
        series[axis].push(value);
        if (value === null)
          haveNull = true;
        else
          haveNonNull = true;
      });
    }
  }
  pushdp(series, buildinf, ctime, haveNull, haveNonNull);

  // Push a dummy null point at the end of the series to force the zoom to end
  // exactly there
  builds.push({ time: start, timerange: [ start, start ] });
  builds.push({ time: stop, timerange: [ stop, stop ] });
  var seriesData = [];
  for (var axis in data) {
    data[axis].push([ start, null ]);
    data[axis].push([ stop, null ]);
    seriesData.push({ name: axis, label: this.axis[axis], data: data[axis], buildinfo: builds });
  }

  return seriesData;
}

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
}

// Either zoom in on a datapoint or trigger a graph zoom or do nothing.
Plot.prototype.onClick = function(item) {
  if (item) {
    // Clicked an item, switch tooltip to build detail mode
    this.tooltip.handleClick();
  } else if (this.highlighted) {
    // Clicked on highlighted zoom space, do a graph zoom

    // Extend the range if necessary to cover builds part of the condensed points.
    // Fixes, for instance, a condensed point with a timestamp of 'april 4th'
    // that contains builds through april 4th at 4pm. If your selection includes
    // that point, you expect to get all builds that that point represents
    var buildinfo = this.flot.getData()[0].buildinfo;
    var firstbuild = 0;
    for (var i = 0; i < buildinfo.length; i++) {
      if (buildinfo[i]['time'] < this.highlightRange[0]) continue;
      if (buildinfo[i]['time'] > this.highlightRange[1]) break;
      if (!firstbuild) firstbuild = i;
    }
    var buildrange = getBuildTimeRange(buildinfo[firstbuild], buildinfo[Math.min(i-1, buildinfo.length - 1)]);
    var zoomrange = [];
    zoomrange[0] = Math.min(this.highlightRange[0], buildrange[0]);
    zoomrange[1] = Math.max(this.highlightRange[1], buildrange[1]);
    this.setZoomRange(zoomrange);
  }
}

Plot.prototype._drawAnnotations = function() {
  var self = this;
  this.annotations.empty();

  function includeAnno(anno) {
    if (gQueryVars['mobile'] && anno['mobile'] === false)
        return false;
    if (!gQueryVars['mobile'] && anno['desktop'] === false)
        return false;
    if (anno['whitelist'] && anno['whitelist'].indexOf(self.name) == -1)
        return false;
    return true;
  }

  function dateStamp(msg, time) {
    return '<div class="grey">' + prettyDate(time / 1000) + '</div>' + msg;
  }

  // Determine the pixels:time ratio for this zoom level
  var xaxis = this.flot.getAxes().xaxis;
  var secondsPerPixel = xaxis.c2p(1) - xaxis.c2p(0);
  var mergeTime = gAnnoMergeDist * secondsPerPixel * 1000;
  var mergedAnnotations = [];
  for (var i = 0; i < gAnnotations.length; i++) {
    if (!includeAnno(gAnnotations[i]))
      continue;
    var starttime = gAnnotations[i]['date'].getTime();
    var timesum = starttime;
    var msg = dateStamp(gAnnotations[i]['msg'], starttime);
    var elements = 1;
    while (i + 1 < gAnnotations.length &&
           gAnnotations[i + 1]['date'].getTime() - starttime < mergeTime) {
      i++;
      var merge = gAnnotations[i];
      if (!includeAnno(merge))
        continue;
      elements++;
      var mergetime = merge['date'].getTime();
      timesum += mergetime;
      msg += "<hr>" + dateStamp(merge['msg'], mergetime);
    }
    mergedAnnotations.push({ 'date': new Date(timesum / elements),
                             'msg': msg });
  }
  for (var i = 0; i < mergedAnnotations.length; i++) {
    (function () {
      var anno = mergedAnnotations[i];

      var date = anno['date'];

      var div = $.new('div').addClass('annotation').text('?');
      self.annotations.append(div);
      var tooltiptop = parseInt(div.css('padding-top')) * 2 + 5
                     + parseInt(div.css('height'))
                     + parseInt(self.annotations.css('top'))
                     + self.flot.getPlotOffset().top
                     + self.obj.offset().top - self.container.offset().top;
      var divwidth = parseInt(div.css('padding-left'))
                   + parseInt(div.css('width'));
      var left = xaxis.p2c(date.getTime() / 1000) - divwidth / 2;

      if (left + divwidth + 5 > self.flot.width() ||
          left - 5 < 0) {
        div.remove();
        return;
      }

      div.css('left', left);

      div.mouseover(function() {
        // Don't hijack a tooltip that's in the process of zooming
        if (self.tooltip.isZoomed())
          return;
        self.tooltip.empty();
        self.tooltip.append(anno['msg']);
        var x = left
              - parseInt(self.tooltip.obj.css('width')) / 2
              - parseInt(self.tooltip.obj.css('padding-left'))
              - gTooltipOffset
              + divwidth / 2
              + self.flot.getPlotOffset().left;
        self.tooltip.hover(x, tooltiptop);
      });
      div.mouseout(function() { self.tooltip.unHover(); });
    })();
  }
}

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
/*
  var minZoomDays = 3;
  if (xaxis.max - xaxis.min <= minZoomDays * 24 * 60 * 60) {
    this.highlighted = false;
    this.zoomSelector.stop().fadeTo(50, 0);
    return;
  }
*/

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
}

Plot.prototype.hideHighlight = function() {
  if (this.highlighted) {
    this.highlighted = false;
    this.zoomSelector.stop().fadeTo(250, 0);
  }
}

// If we're hovering over a point, show a tooltip. Otherwise, show the
// zoom selector if we're not beyond our zoom-in limit
Plot.prototype.onHover = function(item, pos) {
  if (this.tooltip.isZoomed()) {
    return;
  }
  var self = this;
  if (item &&
      (!this.hoveredItem || (item.dataIndex !== this.hoveredItem.dataIndex))) {
    this.hideHighlight();
    this.tooltip.showBuild(item.series.label,
                           item.series.data,
                           item.series.buildinfo,
                           item.dataIndex,
                           item.series.name);

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
}


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
      for (var ind = 0; ind < gData.commits.length; ind++) {
        var t = gData.commits[ind].time;
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
      for (var ind = 0; ind < gData.commits.length; ind++) {
        var commit = gData.commits[ind];
        gCommits[commit.commit] = commit;
        commit.results = {};
        if (ind > 0) {
          var prevCommit = gData.commits[ind-1];
          prevCommit.next = commit;
          commit.prev = prevCommit;
        }
      }

      gTests = {};
      for (var ind = 0; ind < gData.tests.length; ind++) {
        var test = gData.tests[ind];
        gTests[test.id] = test;

        var $option = $.new('option', {'value' : test.id}).text(test.name);
        if (test.id == gCurrentTestID)
          $option.attr('selected', 'selected');
        $('#testSelector').append($option);
      }

      for (var ind = 0; ind < gData.results.length; ind++) {
        var result = gData.results[ind];
        if (result.commit in gCommits)
          gCommits[result.commit].results[result.testID] = result;
      }

      $('#graphs h3').remove();
      gPlot = new Plot($('#graphs'));
      selectTest(gCurrentTestID);

      // Show stats
      let stats =
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

  // Handler to close zoomed tooltips upon clicking outside of them
  $('body').bind('click', function(e) {
    if (!$(e.target).is('.tooltip') && !$(e.target).parents('.graphContainer').length)
      $('.tooltip.zoomed').each(function(ind,ele) {
        $(ele).data('owner').unzoom();
      });
  });

  $('#testSelector').on('change keyup', function() {
    selectTest(this.value);
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
    }, 1000, function() { rotating = false });
    adjectiveIndex = (adjectiveIndex+1)%3;
  }
  $('#page-header').click(rotateAdjective);
});

function selectTest(testID) {
  gCurrentTestID = testID;
  gPlot.updateData();
  $('#test-id').text(testID);
  $('#test-name').text(gTests[testID].name.replace(/ - /g, ' – '));
  $('#test-description').html(gTests[testID].description);
}
