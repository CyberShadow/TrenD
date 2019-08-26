#!/bin/bash
sqlite3 data/trend.s3db 'DELETE FROM [Commits] WHERE [Error] IS NOT NULL'
sqlite3 data/trend.s3db 'DELETE FROM [Results] WHERE [Error] IS NOT NULL'
