CREATE TABLE [Commits] (
[Commit] CHAR(40) NOT NULL,
[Message] TEXT NOT NULL,
[Time] INTEGER NOT NULL,
[Error] TEXT NULL
);

CREATE UNIQUE INDEX [CommitIndex] ON [Commits] (
[Commit] ASC
);

CREATE TABLE [Results] (
[TestID] VARCHAR(100) NOT NULL,
[Commit] CHAR(40) NOT NULL,
[Value] INTEGER NOT NULL,
[Error] TEXT NULL
);

CREATE UNIQUE INDEX [ResultIndex] ON [Results] (
[TestID] ASC,
[Commit] ASC
);
